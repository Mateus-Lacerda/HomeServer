import SwiftUI

// Lógica de aproximação baseada no progress
private func calculatePillOffset(proxy: GeometryProxy, p: CGFloat) -> CGFloat {
  let currentX = proxy.frame(in: .named("PILL_LOCAL")).midX
  // 65 é o centro aproximado (130 / 2)
  let targetX: CGFloat = 65
  return (targetX - currentX) * p
}

struct ExpandableMergingGlassContainer<Content: View, MergedLabel: View>: View {
  var size: CGSize
  var progress: CGFloat
  @ViewBuilder var content: Content
  @ViewBuilder var mergedLabel: MergedLabel

  @State private var containerWidth: CGFloat = 0

  var body: some View {
    ZStack(alignment: .center) {
      HStack(spacing: spacing) {
        ForEach(subviews: content) { subview in
          subview
            .blur(radius: 15 * (progress == 1.0 ? 1 : 0))  // Só blura na fusão total
            .opacity(progress == 1.0 ? 0 : 1)
            .frame(width: size.width, height: size.height)
            .glassEffect(.regular, in: .capsule)
            .visualEffect { [progress] content, proxy in
              content.offset(x: calculatePillOffset(proxy: proxy, p: progress))
            }
            .fixedSize()
        }
      }
      // Mantém o espaço ocupado para a pílula não sumir
      .frame(width: max(130, containerWidth))

      // A pílula grande fundida
      mergedLabel
        .glassEffect(.regular, in: .capsule)
        .opacity(progress == 1.0 ? 1 : 0)
        .scaleEffect(progress == 1.0 ? 1.0 : 0.8)
        .blur(radius: progress == 1.0 ? 0 : 10)
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: {
      containerWidth = $0
    }
    .coordinateSpace(.named("PILL_LOCAL"))
    .scaleEffect(x: 1 + (scaleProgress * 0.15), y: 1 - (scaleProgress * 0.15))
    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
  }

  private var scaleProgress: CGFloat {
    progress > 0.5 ? (1 - progress) / 0.5 : (progress / 0.5)
  }

  private var spacing: CGFloat {
    // Diminui o espaço de 40 para 10 no pre-activated, e para 0 na fusão
    if progress >= 1.0 { return 0 }
    return 40 - (100 * progress)  // Faz as pílulas "correrem" uma para a outra
  }
}
