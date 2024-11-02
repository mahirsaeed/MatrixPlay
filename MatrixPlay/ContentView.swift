//
//  ContentView.swift
//  MatrixPlay
//
//  Created by Mahir Saeed on 02/11/2024.
//

import SwiftUI
import Combine

enum DotShape: String, CaseIterable, Identifiable {
    case circle, square, star
    var id: String { rawValue }
}

struct Dot: Identifiable {
    let id = UUID()
    var x, y: CGFloat
    let originX, originY: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
}

struct ContentView: View {
    var body: some View {
        MatrixEffectView()
    }
}



#Preview {
    ContentView()
}

class MatrixEffectModel: ObservableObject {
    @Published var dots = [Dot]()
    @Published var selectedShape: DotShape = .circle // Default shape
    var touchLocation = CGPoint(x: -1000, y: -1000)
    // Computed property for dot size based on selected shape
    var dotSize: CGFloat {
        selectedShape == .star ? 8 : 5
    }
    let dotSpacing: CGFloat = 20
    let touchBoundingSize: CGFloat = 50
    let dotInertia: CGFloat = 0.4
    private let touchBoundingSizeSquared: CGFloat
    
    init() {
        touchBoundingSizeSquared = touchBoundingSize * touchBoundingSize
    }
    
    func initializeDots(size: CGSize) {
        let rows = Int(size.height / dotSpacing)
        let columns = Int(size.width / dotSpacing)
        dots = (0..<rows * columns).map { index in
            let x = CGFloat(index % columns) * dotSpacing
            let y = CGFloat(index / columns) * dotSpacing
            return Dot(x: x, y: y, originX: x, originY: y)
        }
    }
    
    func updateDots() {
        dots = dots.map { dot in
            var updatedDot = dot
            let dx = touchLocation.x - dot.x
            let dy = touchLocation.y - dot.y
            let distanceSquared = dx * dx + dy * dy
            
            if distanceSquared < touchBoundingSizeSquared {
                let distance = sqrt(distanceSquared)
                let force = (touchBoundingSize - distance) / touchBoundingSize
                let angle = atan2(dy, dx)
                let targetX = dot.x - cos(angle) * force * 20
                let targetY = dot.y - sin(angle) * force * 20
                
                updatedDot.vx += (targetX - dot.x) * dotInertia
                updatedDot.vy += (targetY - dot.y) * dotInertia
            }
            
            updatedDot.vx *= 0.9
            updatedDot.vy *= 0.9
            
            updatedDot.x += updatedDot.vx
            updatedDot.y += updatedDot.vy
            
            let dx2 = dot.originX - updatedDot.x
            let dy2 = dot.originY - updatedDot.y
            if dx2 * dx2 + dy2 * dy2 > 1 {
                updatedDot.x += dx2 * 0.03
                updatedDot.y += dy2 * 0.03
            }
            
            return updatedDot
        }
    }
}

struct MatrixEffectView: View {
    @StateObject private var model = MatrixEffectModel()
    @State private var dotColor = Color.red
    @State private var showMenu = false
    @GestureState private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    for dot in model.dots {
                        drawShape(at: CGPoint(x: dot.x, y: dot.y), shape: model.selectedShape, size: model.dotSize, context: context)
                    }
                }
                .padding()
                .background(Color.black)
                .gesture(
                    DragGesture()
                        .updating($isDragging) { value, state, _ in
                            state = true
                            model.touchLocation = value.location
                        }
                        .onEnded { _ in
                            model.touchLocation = CGPoint(x: -1000, y: -1000)
                        }
                )
                
                // Settings Menu
                HStack {
                   
                    if showMenu {
                        SettingsMenu(selectedColor: $dotColor, selectedShape: $model.selectedShape)
                            .frame(width: 200)
                            .transition(.move(edge: .leading))
                            .animation(.easeInOut, value: showMenu)
                    }
                    
                    // Toggle button for menu
                    VStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showMenu.toggle()
                            }
                        }) {
                            Image(systemName: showMenu ? "arrow.left.circle" : "arrow.right.circle")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .padding()
                                .foregroundColor(.white)
                                
                        }
                        
                        Spacer()
                    }
                  

                    Spacer()
                }

               
            }
            .onAppear {
                model.initializeDots(size: geometry.size)
                startAnimation()
            }
        }
    }
    
    private func drawShape(at position: CGPoint, shape: DotShape, size: CGFloat, context: GraphicsContext) {
        let rect = CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size)
        
        switch shape {
        case .circle:
            context.fill(Path(ellipseIn: rect), with: .color(dotColor))
        case .square:
            context.fill(Path(rect), with: .color(dotColor))
        case .star:
            let starPath = Path { path in
                let center = CGPoint(x: position.x, y: position.y)
                let pointsOnStar = 5
                let radius: CGFloat = size / 2
                let innerRadius: CGFloat = radius / 2
                
                for i in 0..<pointsOnStar * 2 {
                    let angle = CGFloat(i) * (.pi / CGFloat(pointsOnStar))
                    let radiusToUse = i % 2 == 0 ? radius : innerRadius
                    let point = CGPoint(
                        x: center.x + cos(angle) * radiusToUse,
                        y: center.y + sin(angle) * radiusToUse
                    )
                    if i == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                path.closeSubpath()
            }
            context.fill(starPath, with: .color(dotColor))
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            model.updateDots()
        }
    }
}

// Combined Settings Menu
struct SettingsMenu: View {
    @Binding var selectedColor: Color
    @Binding var selectedShape: DotShape

    var body: some View {
        VStack(alignment: .leading) {
            Text("Select Dot Color")
                .font(.headline)
            ColorPicker("Dot Color", selection: $selectedColor)
                .labelsHidden()
                .padding()

            Divider()
                .padding(.vertical)

            Text("Select Dot Shape")
                .font(.headline)
            Picker("Shape", selection: $selectedShape) {
                ForEach(DotShape.allCases, id: \.self) { shape in
                    Text(shape.rawValue.capitalized).tag(shape)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
        }
        .padding()
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct ColorPickerMenu: View {
    @Binding var selectedColor: Color

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("Select Dot Color")
                    .font(.headline)
                ColorPicker("Dot Color", selection: $selectedColor)
                    .labelsHidden()
                    .padding()
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(10)
            .position(x: geometry.size.width / 2, y: 100)
        }
    }
}

struct ShapePickerMenu: View {
    @Binding var selectedShape: DotShape

    var body: some View {
        GeometryReader { geometry in
            HStack {
                ForEach(DotShape.allCases, id: \.self) { shape in
                    Text(shape.rawValue.capitalized)
                        .padding()
                        .background(selectedShape == shape ? Color.gray.opacity(0.5) : Color.clear)
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedShape = shape
                        }
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(10)
            .position(x: geometry.size.width / 2, y: geometry.size.height - 100)
        }
    }
}


