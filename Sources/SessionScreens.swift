import UIKit

/// "m:ss", or "h:mm:ss" from one hour up.
func clock(_ t: TimeInterval) -> String {
    let s = max(0, Int(t.rounded(.up)))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                     : String(format: "%d:%02d", s / 60, s % 60)
}

/// A centered message; used for the lock countdown and the "YouTube is off" placeholder.
final class MessageViewController: UIViewController {
    let label = UILabel()
    init(_ text: String) {
        super.init(nibName: nil, bundle: nil)
        label.text = text
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .title2)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }
}

/// Start screen: optional search terms (comma separated, recent ones as chips) + minutes (1...90).
final class SetupViewController: UIViewController {
    private let recent: [String]
    private let onStart: ([String], Int) -> Void
    private let termsField = UITextField()
    private let minutesField = UITextField()
    private let startButton = UIButton(type: .system)

    init(recent: [String], onStart: @escaping ([String], Int) -> Void) {
        self.recent = recent
        self.onStart = onStart
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = "Was willst du sehen?"
        title.font = .preferredFont(forTextStyle: .title1)

        termsField.placeholder = "z. B. motivation, gaming (leer = nur Instagram)"
        minutesField.placeholder = "Minuten (max. \(Session.maxMinutes))"
        minutesField.keyboardType = .numberPad
        for f in [termsField, minutesField] {
            f.borderStyle = .roundedRect
            f.clearButtonMode = .whileEditing
            f.addTarget(self, action: #selector(validate), for: .editingChanged)
        }
        termsField.autocapitalizationType = .none

        let recentRow = row(recent.map { t in button(t) { [weak self] in self?.append(t) } })
        let minuteRow = row([10, 15, 30, 60].map { m in button("\(m) Min") { [weak self] in
            self?.minutesField.text = "\(m)"; self?.validate()
        } })

        startButton.setTitle("Los", for: .normal)
        startButton.titleLabel?.font = .preferredFont(forTextStyle: .title2)
        startButton.addTarget(self, action: #selector(start), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, termsField, recentRow, minutesField, minuteRow, startButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        recentRow.isHidden = recent.isEmpty
        validate()
    }

    private var minutes: Int? {
        Int(minutesField.text ?? "").flatMap { (1...Session.maxMinutes).contains($0) ? $0 : nil }
    }

    @objc private func validate() { startButton.isEnabled = minutes != nil }

    @objc private func start() {
        guard let m = minutes else { return }
        onStart((termsField.text ?? "").split(separator: ",").map(String.init), m)
    }

    private func append(_ term: String) {
        let cur = (termsField.text ?? "").trimmingCharacters(in: .whitespaces)
        termsField.text = cur.isEmpty ? term : cur + ", " + term
    }

    private func button(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        var cfg = UIButton.Configuration.tinted()
        cfg.title = title
        return UIButton(configuration: cfg, primaryAction: UIAction { _ in action() })
    }

    // ponytail: one non-wrapping row; many recent terms get squeezed, wrap or scroll if that bites.
    private func row(_ views: [UIView]) -> UIStackView {
        let r = UIStackView(arrangedSubviews: views)
        r.spacing = 8
        r.distribution = .fillProportionally
        return r
    }
}
