#include "check-queue.hpp"

#include <QSignalSpy>
#include <QtTest>

#include <algorithm>

#include "../play-queue.hpp"
#include "../track-model.hpp"
#include "../track.hpp"

// a song in the helper's shape
static QVariantMap helper_song(const QString& id, const QString& title = QString())
{
    return {
        {"video_id", id},
        {"title", title.isEmpty() ? id : title},
        {"artist", "Artist " + id},
        {"album", "Album " + id},
        {"duration_seconds", 215},
        {"thumbnail_url", "https://example.test/" + id + ".jpg"},
    };
}

// songs a, b, c, ...
static void fill_results(TrackModel& results, int count)
{
    QVariantList songs;
    for (int index = 0; index < count; ++index)
    {
        songs.append(helper_song(QString(QChar('a' + index))));
    }
    results.set_tracks(songs);
}

static QString ids_of(const PlayQueue& queue)
{
    QString ids;
    for (int row = 0; row < queue.rowCount(); ++row)
    {
        ids += queue.trackAt(row).value("videoId").toString();
    }
    return ids;
}

void CheckQueue::trackRoundTrip()
{
    const Track track = Track::from_helper(helper_song("x", "Moonlit Cartography"));
    QCOMPARE(track.video_id, QString("x"));
    QCOMPARE(track.title, QString("Moonlit Cartography"));
    QCOMPARE(track.duration_seconds, 215);

    const QVariantMap for_qml = track.to_qml();
    QCOMPARE(for_qml.value("videoId").toString(), QString("x"));
    QCOMPARE(for_qml.value("durationSeconds").toInt(), 215);
    QCOMPARE(for_qml.value("thumbnailUrl").toString(), QString("https://example.test/x.jpg"));

    const Track back = Track::from_qml(for_qml);
    QCOMPARE(back.video_id, track.video_id);
    QCOMPARE(back.artist, track.artist);
    QCOMPARE(back.album, track.album);
    QCOMPARE(back.thumbnail_url, track.thumbnail_url);
}

void CheckQueue::trackNeedsVideoId()
{
    QVERIFY(!Track::from_helper({{"title", "No id"}}).is_valid());
    QVERIFY(Track::from_helper(helper_song("x")).is_valid());
}

void CheckQueue::setTracksDropsSongsWithoutId()
{
    TrackModel results;
    results.set_tracks({helper_song("a"), QVariantMap{{"title", "No id"}}, helper_song("b")});
    QCOMPARE(results.rowCount(), 2);
    QCOMPARE(results.trackAt(1).value("videoId").toString(), QString("b"));
    QVERIFY(results.trackAt(5).isEmpty());
}

void CheckQueue::totalSeconds()
{
    TrackModel results;
    QSignalSpy changed(&results, &TrackModel::changed);
    QCOMPARE(results.total_seconds(), 0);

    fill_results(results, 3);
    QCOMPARE(results.total_seconds(), 3 * 215);

    // same count, different total: qml relies on `changed` firing here
    changed.clear();
    results.removeAt(2);
    results.append(Track::from_helper({{"video_id", "long"}, {"duration_seconds", 3600}}));
    QCOMPARE(results.total_seconds(), 2 * 215 + 3600);
    QVERIFY(changed.count() >= 1);
}

void CheckQueue::playFromQueuesWholeList()
{
    TrackModel results;
    fill_results(results, 4);
    PlayQueue queue;

    queue.playFrom(&results, 2);

    QCOMPARE(ids_of(queue), QString("abcd"));
    QCOMPARE(queue.current(), 2);
    QVERIFY(queue.has_previous());
    QVERIFY(queue.has_next());
    QCOMPARE(queue.up_next_count(), 1);
    QCOMPARE(queue.currentTrack().value("videoId").toString(), QString("c"));

    // the queue keeps its own copy
    results.set_tracks({helper_song("z")});
    QCOMPARE(ids_of(queue), QString("abcd"));
}

void CheckQueue::playFromBadRowDoesNothing()
{
    TrackModel results;
    fill_results(results, 2);
    PlayQueue queue;

    queue.playFrom(&results, 5);
    queue.playFrom(&results, -1);
    queue.playFrom(nullptr, 0);

    QCOMPARE(queue.rowCount(), 0);
    QCOMPARE(queue.current(), -1);
    QVERIFY(!queue.has_next());
    QVERIFY(!queue.has_previous());
    QVERIFY(queue.currentTrack().isEmpty());
}

void CheckQueue::stepStaysInBounds()
{
    TrackModel results;
    fill_results(results, 3);
    PlayQueue queue;
    queue.playFrom(&results, 0);

    QVERIFY(!queue.step(-1));
    QCOMPARE(queue.current(), 0);
    QVERIFY(queue.step(1));
    QVERIFY(queue.step(1));
    QCOMPARE(queue.current(), 2);
    QVERIFY(!queue.step(1));
    QCOMPARE(queue.current(), 2);
    QVERIFY(!queue.has_next());
    QVERIFY(queue.step(-1));
    QCOMPARE(queue.currentTrack().value("videoId").toString(), QString("b"));
}

void CheckQueue::playNextGoesAfterCurrent()
{
    TrackModel results;
    fill_results(results, 3);
    PlayQueue queue;
    queue.playFrom(&results, 1);

    queue.playNext(Track::from_helper(helper_song("x")).to_qml());

    QCOMPARE(ids_of(queue), QString("abxc"));
    QCOMPARE(queue.current(), 1);
    QCOMPARE(queue.up_next_count(), 2);

    // the most recent play next goes first
    queue.playNext(Track::from_helper(helper_song("y")).to_qml());
    QCOMPARE(ids_of(queue), QString("abyxc"));
}

void CheckQueue::playNextOnEmptyQueueBecomesCurrent()
{
    PlayQueue queue;
    queue.playNext(Track::from_helper(helper_song("x")).to_qml());

    QCOMPARE(ids_of(queue), QString("x"));
    QCOMPARE(queue.current(), 0);
    QVERIFY(!queue.has_next());
}

void CheckQueue::addToEndKeepsCurrent()
{
    TrackModel results;
    fill_results(results, 2);
    PlayQueue queue;
    queue.playFrom(&results, 0);

    queue.addToEnd(Track::from_helper(helper_song("x")).to_qml());

    QCOMPARE(ids_of(queue), QString("abx"));
    QCOMPARE(queue.current(), 0);
    QCOMPARE(queue.up_next_count(), 2);

    queue.addToEnd({{"title", "No id"}});
    QCOMPARE(queue.rowCount(), 3);
}

void CheckQueue::removeBeforeCurrentKeepsCurrent()
{
    TrackModel results;
    fill_results(results, 4);
    PlayQueue queue;
    queue.playFrom(&results, 2);

    queue.removeAt(0);

    QCOMPARE(ids_of(queue), QString("bcd"));
    QCOMPARE(queue.current(), 1);
    QCOMPARE(queue.currentTrack().value("videoId").toString(), QString("c"));

    queue.removeAt(2);
    QCOMPARE(ids_of(queue), QString("bc"));
    QCOMPARE(queue.current(), 1);
}

void CheckQueue::currentSongCannotBeRemoved()
{
    TrackModel results;
    fill_results(results, 3);
    PlayQueue queue;
    queue.playFrom(&results, 1);

    queue.removeAt(1);
    queue.removeAt(-1);
    queue.removeAt(9);

    QCOMPARE(ids_of(queue), QString("abc"));
    QCOMPARE(queue.current(), 1);
}

void CheckQueue::clearUpNextKeepsPlayedSongs()
{
    TrackModel results;
    fill_results(results, 4);
    PlayQueue queue;
    queue.playFrom(&results, 1);

    queue.clearUpNext();

    QCOMPARE(ids_of(queue), QString("ab"));
    QCOMPARE(queue.current(), 1);
    QVERIFY(!queue.has_next());
    QVERIFY(queue.has_previous());

    QSignalSpy changed(&queue, &PlayQueue::placeChanged);
    queue.clearUpNext();
    QCOMPARE(changed.count(), 0);
}

void CheckQueue::jumpTo()
{
    TrackModel results;
    fill_results(results, 4);
    PlayQueue queue;
    queue.playFrom(&results, 0);

    QVERIFY(queue.jumpTo(3));
    QCOMPARE(queue.current(), 3);
    QVERIFY(!queue.jumpTo(4));
    QVERIFY(!queue.jumpTo(-1));
    QCOMPARE(queue.current(), 3);
}

void CheckQueue::playShuffledQueuesEverySongOnce()
{
    TrackModel results;
    fill_results(results, 12);
    PlayQueue queue;
    QSignalSpy changed(&queue, &PlayQueue::placeChanged);

    queue.playShuffled(&results);

    // order is random, so only check it's the same set
    QCOMPARE(queue.rowCount(), 12);
    QString ids = ids_of(queue);
    std::sort(ids.begin(), ids.end());
    QCOMPARE(ids, QString("abcdefghijkl"));
    QCOMPARE(queue.current(), 0);
    QVERIFY(queue.has_next());
    QVERIFY(!queue.has_previous());
    QCOMPARE(changed.count(), 1);

    // the source list isn't shuffled in place
    QCOMPARE(results.trackAt(0).value("videoId").toString(), QString("a"));
}

void CheckQueue::playShuffledEmptyDoesNothing()
{
    TrackModel empty;
    TrackModel results;
    fill_results(results, 3);
    PlayQueue queue;
    queue.playFrom(&results, 1);
    QSignalSpy changed(&queue, &PlayQueue::placeChanged);

    queue.playShuffled(&empty);
    queue.playShuffled(nullptr);

    QCOMPARE(ids_of(queue), QString("abc"));
    QCOMPARE(queue.current(), 1);
    QCOMPARE(changed.count(), 0);
}

void CheckQueue::placeChangedOnlyOnRealChanges()
{
    TrackModel results;
    fill_results(results, 3);
    PlayQueue queue;
    QSignalSpy changed(&queue, &PlayQueue::placeChanged);

    queue.playFrom(&results, 0);
    QCOMPARE(changed.count(), 1);
    queue.step(1);
    QCOMPARE(changed.count(), 2);
    queue.addToEnd(Track::from_helper(helper_song("x")).to_qml());
    QCOMPARE(changed.count(), 3);
    queue.removeAt(3);
    QCOMPARE(changed.count(), 4);

    queue.jumpTo(1);
    QCOMPARE(changed.count(), 4);
}

QTEST_APPLESS_MAIN(CheckQueue)
