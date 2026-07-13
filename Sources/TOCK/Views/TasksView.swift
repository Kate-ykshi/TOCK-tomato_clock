import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingNewCategorySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
                .padding(.top, 36)

            ForEach(appState.categories) { category in
                CategoryCard(
                    category: category,
                    isEditing: appState.isEditingTasks,
                    onRenameCategory: appState.updateCategoryName,
                    onChangeCategoryColor: appState.updateCategoryColor,
                    onDeleteCategory: appState.deleteCategory,
                    onAddTask: appState.addTask,
                    onRenameTask: appState.updateTaskName,
                    onDeleteTask: appState.deleteTask
                )
            }

            Spacer()
        }
        .padding(.horizontal, 34)
        .sheet(isPresented: $isShowingNewCategorySheet) {
            NewCategorySheet(initialColorToken: appState.suggestedCategoryColorToken) { name, colorToken in
                appState.addCategory(name: name, colorToken: colorToken)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("任务")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primaryText)

            if appState.isEditingTasks {
                Button {
                    isShowingNewCategorySheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.tockGreen)
                            .frame(width: 24, height: 24)
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .buttonStyle(.plain)
                .help("新建分类")
            }

            Spacer()

            Button(appState.isEditingTasks ? "完成" : "编辑") {
                appState.isEditingTasks.toggle()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.primaryText)
            .frame(width: 76, height: 38)
            .background(appState.isEditingTasks ? Color.tockGreen.opacity(0.18) : Color.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 19))
            .overlay {
                RoundedRectangle(cornerRadius: 19)
                    .stroke(Color.line)
            }
        }
    }
}

private struct CategoryCard: View {
    let category: FocusCategory
    let isEditing: Bool
    let onRenameCategory: (FocusCategory, String) -> Void
    let onChangeCategoryColor: (FocusCategory, TockColorToken) -> Void
    let onDeleteCategory: (FocusCategory) -> Void
    let onAddTask: (FocusCategory) -> Void
    let onRenameTask: (FocusTask, String) -> Void
    let onDeleteTask: (FocusTask) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    if isEditing {
                        ColorTokenMenu(selectedToken: category.colorToken) { token in
                            onChangeCategoryColor(category, token)
                        }
                    } else {
                        Circle()
                            .fill(category.color)
                            .frame(width: 14, height: 14)
                    }

                    if isEditing {
                        HStack(spacing: 6) {
                            TextField("分类名称", text: Binding(
                                get: { category.name },
                                set: { onRenameCategory(category, $0) }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 42, alignment: .leading)

                            CategoryTextActionButton(title: "添加") {
                                onAddTask(category)
                            }
                            .help("新建任务")

                            CategoryTextActionButton(title: "删除") {
                                onDeleteCategory(category)
                            }
                            .help("删除分类")
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    } else {
                        Text(category.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                    }
                }

                Spacer()

                Text(category.todayTotalText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.bottom, 18)

            Divider()
                .background(Color.line)

            VStack(spacing: 14) {
                if category.visibleTasks.isEmpty {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 6, height: 6)
                        Text(isEditing ? "还没有任务，点上方加号新建一个" : "这个分类还没有任务")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                    }
                    .frame(height: 22)
                }

                ForEach(category.visibleTasks) { task in
                    TaskRow(
                        task: task,
                        isEditing: isEditing,
                        onRenameTask: onRenameTask,
                        onDeleteTask: onDeleteTask
                    )
                }
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(minHeight: 118)
        .cardStyle()
    }
}

private struct TaskRow: View {
    let task: FocusTask
    let isEditing: Bool
    let onRenameTask: (FocusTask, String) -> Void
    let onDeleteTask: (FocusTask) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.black)
                .frame(width: 6, height: 6)

            if isEditing {
                TextField("任务名称", text: Binding(
                    get: { task.name },
                    set: { onRenameTask(task, $0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primaryText.opacity(0.88))
            } else {
                Text(task.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.primaryText.opacity(0.88))
            }

            Spacer()

            Text(task.todayDurationText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primaryText)

            if isEditing {
                DeleteBadgeButton {
                    onDeleteTask(task)
                }
                .help("删除任务")
            }
        }
    }
}

private struct CategoryTextActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
                .frame(height: 20)
        }
        .buttonStyle(.plain)
    }
}

private struct DeleteBadgeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.deleteRed)
                    .frame(width: 16, height: 16)
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
    }
}

private struct ColorTokenMenu: View {
    @State private var isShowingPicker = false

    let selectedToken: TockColorToken
    let onSelect: (TockColorToken) -> Void

    var body: some View {
        Button {
            isShowingPicker.toggle()
        } label: {
            Circle()
                .fill(selectedToken.color)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPicker, arrowEdge: .bottom) {
            VStack(spacing: 10) {
                ForEach(TockColorToken.allCases) { token in
                    Button {
                        onSelect(token)
                        isShowingPicker = false
                    } label: {
                        Circle()
                            .fill(token.color)
                            .frame(width: 18, height: 18)
                            .overlay {
                                if token == selectedToken {
                                    Circle()
                                        .stroke(Color.primaryText.opacity(0.72), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(token.title)
                }
            }
            .padding(12)
            .background(Color.cardBackground)
        }
    }
}
