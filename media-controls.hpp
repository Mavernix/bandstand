#pragma once

#include <QDBusAbstractAdaptor>
#include <QDBusObjectPath>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

// the media keys and the panel's now playing controls. the compositor runs playerctl
// for the media keys, and playerctl talks to players on the session bus over mpris
// (https://specifications.freedesktop.org/mpris-spec/latest/). qml binds the playback
// state to the properties and acts on the requests; this only translates.
class MediaControls : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool playing READ playing WRITE set_playing)
    // a track map (Track::to_qml()), or empty when idle
    Q_PROPERTY(QVariantMap track READ track WRITE set_track)
    Q_PROPERTY(qint64 durationMs READ duration_ms WRITE set_duration_ms)
    Q_PROPERTY(qint64 positionMs READ position_ms WRITE set_position_ms)
    Q_PROPERTY(bool canNext READ can_next WRITE set_can_next)
    Q_PROPERTY(bool canPrevious READ can_previous WRITE set_can_previous)
    Q_PROPERTY(double volume READ volume WRITE set_volume)
    // "off", "all" or "one", as in qml/Playback.qml
    Q_PROPERTY(QString repeat READ repeat WRITE set_repeat)

  public:
    explicit MediaControls(QObject *parent = nullptr);
    ~MediaControls() override;

    bool playing() const;
    QVariantMap track() const;
    qint64 duration_ms() const;
    qint64 position_ms() const;
    bool can_next() const;
    bool can_previous() const;
    double volume() const;
    QString repeat() const;

    void set_playing(bool value);
    void set_track(const QVariantMap& value);
    void set_duration_ms(qint64 value);
    void set_position_ms(qint64 value);
    void set_can_next(bool value);
    void set_can_previous(bool value);
    void set_volume(double value);
    void set_repeat(const QString& value);

    // qml calls this after it jumped somewhere in the song, playerctl and the panel
    // only learn of jumps from this (the position itself isn't announced)
    Q_INVOKABLE void seeked(qint64 position_ms);

    // for the adaptors
    bool has_song() const;
    QString playback_status() const;
    QVariantMap metadata() const;
    QDBusObjectPath track_path() const;

  signals:
    void playPauseRequested();
    void playRequested();
    void pauseRequested();
    void stopRequested();
    void nextRequested();
    void previousRequested();
    void seekRequested(qint64 positionMs);
    void volumeRequested(double volume);
    void repeatRequested(const QString& repeat);
    void raiseRequested();

    // to the adaptor, which puts it on the bus as Seeked(x)
    void announceSeeked(qlonglong position_us);

  private:
    void announce(const QStringList& names);

    bool is_playing = false;
    QVariantMap current_track;
    qint64 length_ms = 0;
    qint64 at_ms = 0;
    bool next_possible = false;
    bool previous_possible = false;
    double current_volume = 1.0;
    QString repeat_mode = QStringLiteral("off");
    QString service_name;
};

// org.mpris.MediaPlayer2: who we are
class MediaPlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ can_quit)
    Q_PROPERTY(bool CanRaise READ can_raise)
    Q_PROPERTY(bool HasTrackList READ has_track_list)
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktop_entry)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supported_uri_schemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ supported_mime_types)

  public:
    explicit MediaPlayerAdaptor(MediaControls *controls);

    bool can_quit() const;
    bool can_raise() const;
    bool has_track_list() const;
    QString identity() const;
    QString desktop_entry() const;
    QStringList supported_uri_schemes() const;
    QStringList supported_mime_types() const;

  public slots:
    void Raise();
    void Quit();

  private:
    MediaControls *controls;
};

// org.mpris.MediaPlayer2.Player: what's playing, and the buttons
class PlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playback_status)
    Q_PROPERTY(QString LoopStatus READ loop_status WRITE set_loop_status)
    Q_PROPERTY(double Rate READ rate)
    Q_PROPERTY(double MinimumRate READ rate)
    Q_PROPERTY(double MaximumRate READ rate)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(double Volume READ volume WRITE set_volume)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(bool CanGoNext READ can_go_next)
    Q_PROPERTY(bool CanGoPrevious READ can_go_previous)
    Q_PROPERTY(bool CanPlay READ can_play)
    Q_PROPERTY(bool CanPause READ can_pause)
    Q_PROPERTY(bool CanSeek READ can_seek)
    Q_PROPERTY(bool CanControl READ can_control)

  public:
    explicit PlayerAdaptor(MediaControls *controls);

    QString playback_status() const;
    QString loop_status() const;
    void set_loop_status(const QString& value);
    double rate() const;
    QVariantMap metadata() const;
    double volume() const;
    void set_volume(double value);
    qlonglong position() const;
    bool can_go_next() const;
    bool can_go_previous() const;
    bool can_play() const;
    bool can_pause() const;
    bool can_seek() const;
    bool can_control() const;

  public slots:
    void Next();
    void Previous();
    void Pause();
    void PlayPause();
    void Stop();
    void Play();
    // offset and position are in microseconds
    void Seek(qlonglong Offset);
    void SetPosition(const QDBusObjectPath& TrackId, qlonglong Position);
    void OpenUri(const QString& Uri);

  signals:
    void Seeked(qlonglong Position);

  private:
    MediaControls *controls;
};
