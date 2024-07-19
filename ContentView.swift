import SwiftUI
import ARKit
import Combine

@main
struct NutriLensApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

struct MainView: View {
    @StateObject private var foodLogViewModel = FoodLogViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ARScanContainerView(foodLogViewModel: foodLogViewModel)
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }
                .tag(0)

            FoodLogView(viewModel: foodLogViewModel)
                .tabItem {
                    Label("Food Log", systemImage: "list.bullet")
                }
                .tag(1)

            NutritionInsightsView(viewModel: foodLogViewModel)
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(.green)
    }
}

struct ARScanContainerView: View {
    @ObservedObject var foodLogViewModel: FoodLogViewModel
    @State private var showingAnalysis = false
    @State private var currentAnalysis: FoodAnalysis?

    var body: some View {
        ZStack {
            ARScanView(foodLogViewModel: foodLogViewModel, showingAnalysis: $showingAnalysis, currentAnalysis: $currentAnalysis)
            VStack {
                Spacer()
                Text("Tap on food to analyze")
                    .font(.headline)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingAnalysis) {
            if let analysis = currentAnalysis {
                FoodAnalysisView(analysis: analysis, onSave: {
                    let newLog = FoodLog(id: UUID().uuidString, foodName: analysis.foodName, calories: analysis.calories, date: Date())
                    foodLogViewModel.addFoodLog(newLog)
                    showingAnalysis = false
                })
            }
        }
    }
}

struct ARScanView: UIViewRepresentable {
    @ObservedObject var foodLogViewModel: FoodLogViewModel
    @Binding var showingAnalysis: Bool
    @Binding var currentAnalysis: FoodAnalysis?

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        arView.session.run(config)
        arView.delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARScanView

        init(_ parent: ARScanView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARSCNView else { return }
            let location = gesture.location(in: arView)
            guard let query = arView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any) else { return }
            let results = arView.session.raycast(query)
            guard let result = results.first else { return }

            let worldCoords = result.worldTransform.columns.3
            let position = SCNVector3(worldCoords.x, worldCoords.y, worldCoords.z)
            captureFood(at: position, in: arView)
        }

        func captureFood(at position: SCNVector3, in arView: ARSCNView) {
            let snapshot = arView.snapshot()
            let lidarData = getLiDARData(in: arView)
            APIService.shared.analyzeFoodImage(snapshot, lidarData: lidarData) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let foodAnalysis):
                        self?.parent.currentAnalysis = foodAnalysis
                        self?.parent.showingAnalysis = true
                    case .failure(let error):
                        print("Error analyzing food: \(error.localizedDescription)")
                    }
                }
            }
        }

        func getLiDARData(in arView: ARSCNView) -> [Float] {
            guard let frame = arView.session.currentFrame,
                  let depthMap = frame.sceneDepth?.depthMap else {
                return []
            }

            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            var depthData = [Float](repeating: 0, count: width * height)

            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
            memcpy(&depthData, baseAddress, width * height * MemoryLayout<Float>.stride)
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)

            return depthData
        }
    }
}

struct FoodAnalysisView: View {
    let analysis: FoodAnalysis
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(analysis.foodName)
                .font(.title)
                .fontWeight(.bold)

            Text("\(analysis.calories) calories")
                .font(.headline)

            Text(analysis.analysis)
                .padding()

            Button("Save to Food Log") {
                onSave()
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct FoodLogView: View {
    @ObservedObject var viewModel: FoodLogViewModel

    var body: some View {
        List {
            ForEach(viewModel.foodLogs) { log in
                VStack(alignment: .leading) {
                    Text(log.foodName)
                        .font(.headline)
                    Text("\(log.calories) calories")
                        .font(.subheadline)
                    Text("\(log.date, style: .date)")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Food Log")
    }
}

struct NutritionInsightsView: View {
    @ObservedObject var viewModel: FoodLogViewModel

    var body: some View {
        Text("Nutrition Insights View")
            .navigationTitle("Nutrition Insights")
    }
}

struct ProfileView: View {
    var body: some View {
        Text("Profile View")
            .navigationTitle("Profile")
    }
}

class FoodLogViewModel: ObservableObject {
    @Published var foodLogs: [FoodLog] = []

    func addFoodLog(_ log: FoodLog) {
        foodLogs.append(log)
    }
}

struct FoodLog: Identifiable {
    let id: String
    let foodName: String
    let calories: Int
    let date: Date
}

struct FoodAnalysis: Identifiable {
    let id = UUID()
    let foodName: String
    let calories: Int
    let analysis: String
}

class APIService {
    static let shared = APIService()

    func analyzeFoodImage(_ image: UIImage, lidarData: [Float], completion: @escaping (Result<FoodAnalysis, Error>) -> Void) {
        // Implement API call to backend
    }
}
