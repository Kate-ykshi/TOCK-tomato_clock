import SwiftUI

struct NewCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var categoryName = ""
    @State private var selectedColorToken: TockColorToken

    let onCreate: (String, TockColorToken) -> Void

    init(
        initialColorToken: TockColorToken = .tockGreen,
        onCreate: @escaping (String, TockColorToken) -> Void
    ) {
        _selectedColorToken = State(initialValue: initialColorToken)
        self.onCreate = onCreate
    }

    private var canCreate: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("新建分类")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                Text("给任务一个温和的颜色线索。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("名称")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondaryText)

                TextField("例如：学习、运动、写作", text: $categoryName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.line)
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("颜色")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondaryText)

                HStack(spacing: 12) {
                    ForEach(TockColorToken.allCases) { token in
                        Button {
                            selectedColorToken = token
                        } label: {
                            Circle()
                                .fill(token.color)
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if selectedColorToken == token {
                                        Circle()
                                            .stroke(Color.primaryText.opacity(0.7), lineWidth: 2)
                                            .frame(width: 31, height: 31)
                                    }
                                }
                                .help(token.title)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            HStack {
                Button("取消") {
                    dismiss()
                }
                .secondarySheetButton()

                Spacer()

                Button("创建") {
                    onCreate(categoryName.trimmingCharacters(in: .whitespacesAndNewlines), selectedColorToken)
                    dismiss()
                }
                .primarySheetButton()
                .disabled(!canCreate)
                .opacity(canCreate ? 1 : 0.45)
            }
        }
        .padding(24)
        .frame(width: 380, height: 310)
        .background(Color.appBackground)
    }
}

private extension Button {
    func primarySheetButton() -> some View {
        self
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: 86, height: 38)
            .background(Color.tockGreen)
            .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    func secondarySheetButton() -> some View {
        self
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.primaryText)
            .frame(width: 74, height: 38)
            .background(Color.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(Color.line)
            }
    }
}
