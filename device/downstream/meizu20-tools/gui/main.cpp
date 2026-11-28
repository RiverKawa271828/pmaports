/* main.cpp — RingLight GUI shell: loads the QML UI and applies modes.
 * Arm and Lights-off are password-gated through `pkexec led-helper`
 * (polkit action org.meizu20.tools.led-control, auth_admin: prompts EVERY
 * time — user round 136 wants symmetric confirmation to avoid accidental
 * taps; systemd's manage-unit-files action can't be scoped per-unit, the
 * journal showed it both denied and password-prompting inconsistently).
 * The UI state only updates after the password succeeds, so every press
 * has visible feedback. Row-click preview stays password-free: transient
 * 10s, no state change (its unit restart is allowed by 50-ringlight.rules
 * for active local sessions). Armed state = unit enabled + mode file. */
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QObject>
#include <QTimer>

static const QString MODE_PATH = QStringLiteral("/var/lib/ringlight/mode");
static const QString UNIT = QStringLiteral("ringlight-boot.service");
static const QString HELPER = QStringLiteral("/usr/lib/ringlight/led-helper");

static bool write_mode(const QString &mode) {
	QDir().mkpath(QStringLiteral("/var/lib/ringlight"));
	QFile f(MODE_PATH);
	if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
		return false;
	f.write((mode + QStringLiteral("\n")).toUtf8());
	return f.error() == QFileDevice::NoError;
}

class RingCtl : public QObject {
	Q_OBJECT
	Q_PROPERTY(QString bootMode MEMBER m_bootMode NOTIFY bootModeChanged)
public:
	using QObject::QObject;
	QString bootMode() const { return m_bootMode; }
	Q_INVOKABLE QString currentMode() const {
		QFile f(MODE_PATH);
		if (!f.open(QIODevice::ReadOnly))
			return QStringLiteral("off");
		QString s = QString::fromUtf8(f.readAll()).trimmed();
		return s.isEmpty() ? QStringLiteral("off") : s;
	}
	/* armed = unit enabled + file mode; anything else reads as "off".
	 * QML calls this at startup, so no ringctl method runs at QML-load
	 * time (the old load-time binding threw TypeError: of null). Emits
	 * unconditionally: if any load-time binding was disturbed, this
	 * re-evaluates every checked binding on completion. */
	Q_INVOKABLE void refresh() {
		QProcess p;
		p.start(QStringLiteral("systemctl"), { QStringLiteral("is-enabled"), UNIT });
		p.waitForFinished(2000);
		QString state = QString::fromUtf8(p.readAllStandardOutput()).trimmed();
		m_bootMode = (state == QStringLiteral("enabled"))
			? currentMode() : QStringLiteral("off");
		emit bootModeChanged();
	}
	/* password-gated: arm the boot animation (enable + restart = plays now) */
	Q_INVOKABLE void select(const QString &mode) {
		run_helper({ QStringLiteral("arm"), mode }, [this, mode] {
			m_bootMode = mode;
			emit bootModeChanged();
		});
	}
	/* password-gated: master off (disable + stop, stays dark across boots) */
	Q_INVOKABLE void lightsOff() {
		run_helper({ QStringLiteral("off") }, [this] {
			m_bootMode = QStringLiteral("off");
			emit bootModeChanged();
		});
	}
	Q_INVOKABLE void preview(const QString &mode) { /* 10s try, no state change */
		QString keep = m_bootMode;
		if (!write_mode(mode))
			return;
		QProcess::startDetached(QStringLiteral("systemctl"),
			{ QStringLiteral("restart"), UNIT });
		QTimer::singleShot(11000, [keep] { write_mode(keep); });
	}
signals:
	void bootModeChanged();

private:
	void run_helper(const QStringList &args, const std::function<void()> &onOk) {
		if (m_pending) /* one dialog at a time */
			return;
		m_pending = true;
		auto *p = new QProcess(this);
		connect(p, &QProcess::finished, this,
			[this, p, onOk](int rc, QProcess::ExitStatus st) {
				m_pending = false;
				p->deleteLater();
				/* cancel / auth failure leaves the UI untouched */
				if (st == QProcess::NormalExit && rc == 0)
					onOk();
			});
		p->start(QStringLiteral("pkexec"), QStringList() << HELPER << args);
	}
	bool m_pending = false;
	QString m_bootMode = QStringLiteral("off");
};

int main(int argc, char **argv) {
	QGuiApplication app(argc, argv);
	QQmlApplicationEngine engine;
	RingCtl ctl;
	ctl.refresh();
	engine.rootContext()->setContextProperty(QStringLiteral("ringctl"), &ctl);
	engine.load(QStringLiteral("/usr/share/ringlight/RingLight.qml"));
	if (engine.rootObjects().isEmpty())
		return 1;
	return app.exec();
}
#include "main.moc"
