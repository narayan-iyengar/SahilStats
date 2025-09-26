// In LottieView.swift

import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    var name: String
    var loopMode: LottieLoopMode = .loop

    func makeUIView(context: Context) -> some UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView()

        // --- NEW, MORE ROBUST LOADING LOGIC ---
        // Find the exact path to your animation file in the app bundle.
        // Make sure the file extension here matches your file ('lottie' or 'json').
        guard let path = Bundle.main.path(forResource: name, ofType: "json") else {
            print("Error: Lottie file '\(name).json' not found.")
            return view
        }
        
        // Load the animation from the specific file path.
        animationView.animation = LottieAnimation.filepath(path)
        // --- END OF NEW LOGIC ---

        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.play()
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
