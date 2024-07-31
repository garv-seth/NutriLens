import SwiftUI

struct FoodScanView: View {
    @State private var image: UIImage?
    @State private var analysis: FoodAnalysis?
    @State private var isImagePickerPresented = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding()
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                }

                if let analysis = analysis {
                    AnalysisView(analysis: analysis)
                        .transition(.move(edge: .bottom))
                }

                Button(action: {
                    isImagePickerPresented = true
                }) {
                    Label("Scan Food", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Food Scanner")
            .sheet(isPresented: $isImagePickerPresented, onDismiss: analyzeImage) {
                ImagePicker(image: $image)
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private func analyzeImage() {
        if let image = image {
            withAnimation {
                analysis = nil
            }
            FoodAnalysisService.analyzeFood(image: image) { result in
                withAnimation {
                    self.analysis = result
                }
            }
        }
    }
}

struct AnalysisView: View {
    let analysis: FoodAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(analysis.foodName)
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(analysis.calories) calories")
            }

            Text(analysis.analysis)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding()
    }
}
