// Shared UI state enums.
import Foundation

enum CommandPalettePresentation: Equatable {
    case sidebar
    case centered
}

enum SidebarPage: Equatable {
    case library
    case space(UUID)
}
