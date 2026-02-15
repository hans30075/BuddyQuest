import SwiftUI
import BuddyQuestKit

/// A simple arithmetic gate to verify a parent (not a young child) is accessing the dashboard.
/// Generates random multiplication problems that are easy for adults but challenging for K-5 kids.
struct ParentGateView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var factorA: Int = 0
    @State private var factorB: Int = 0
    @State private var userAnswer: String = ""
    @State private var isWrong = false
    @State private var passed = false

    var body: some View {
        if passed {
            ParentDashboardView()
        } else {
            gateContent
        }
    }

    // MARK: - Gate UI

    private var gateContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding()

            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Parent Verification")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Solve this to access the progress dashboard:")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)

                // Math problem
                Text("\(factorA) × \(factorB) = ?")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)

                // Answer field
                HStack(spacing: 12) {
                    TextField("Answer", text: $userAnswer)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 120)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onSubmit { checkAnswer() }

                    Button("Check") { checkAnswer() }
                        .buttonStyle(.borderedProminent)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .disabled(userAnswer.isEmpty)
                }

                if isWrong {
                    Text("That's not right — try again!")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            }

            Spacer()
            Spacer()
        }
        .frame(minWidth: 400, minHeight: 350)
        .onAppear { generateProblem() }
    }

    // MARK: - Logic

    private func generateProblem() {
        factorA = Int.random(in: 7...19)
        factorB = Int.random(in: 6...14)
        userAnswer = ""
        isWrong = false
    }

    private func checkAnswer() {
        let expected = factorA * factorB
        if Int(userAnswer.trimmingCharacters(in: .whitespaces)) == expected {
            withAnimation { passed = true }
        } else {
            withAnimation { isWrong = true }
            // Generate a new problem after wrong answer
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                generateProblem()
            }
        }
    }
}
