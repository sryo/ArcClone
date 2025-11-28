# ArcClone - Roadmap v2

A browser built with Swift, SwiftUI, and WebKit that reimagines web browsing with spaces and pinned tabs.

## ✅ Completed Features (v1)

- **Spaces & Tabs**: Workspaces with pinned/today tabs, archiving
- **Profiles**: Isolated browsing data per space
- **Command Palette**: Rich search with suggestions
- **Library**: Downloads, archived tabs, space management
- **Media Integration**: Audio indicators + Now Playing controls
- **Onboarding**: First-run experience with welcome guide
- **UI Polish**: Theme picker, toolbar styling, download animations
- **System Integration**: Passwords, ad blocking

## 🎯 Upcoming Features

### 1. Advanced Tab Management
- [ ] **Tab Search**: Search across all tabs in Command Palette
- [ ] **Tab Preview**: Hover preview thumbnails for tabs
- [ ] **Recently Closed**: Quick access to recently closed tabs
- [ ] **Tab Suspension**: Auto-suspend inactive tabs to save memory
- [ ] **Bulk Actions**: Multi-select tabs for batch operations

### 2. Enhanced Productivity
- [ ] **Split View**: View two tabs side-by-side
- [ ] **Picture-in-Picture**: Detachable video player
- [ ] **Reading Mode**: Clean, distraction-free article reading
- [ ] **Focus Mode**: Hide sidebar/chrome for immersive browsing
- [ ] **Quick Notes**: Take notes linked to specific tabs/sites

### 3. Search & Navigation
- [ ] **History Search**: Full history search in Command Palette
- [ ] **Quick Actions**: Custom keyboard shortcuts for common tasks
- [ ] **Page Search**: Enhanced find-in-page with highlighting
- [ ] **URL Suggestions**: Smart URL completion from history

### 4. Privacy & Security
- [ ] **Cookie Manager**: View and manage cookies per site

### 5. Sync & Backup
- [ ] **iCloud Sync**: Sync spaces/tabs across devices
- [ ] **Session Export**: Export/import spaces and tabs
- [ ] **Crash Recovery**: Auto-save and restore sessions
- [ ] **Scheduled Backups**: Automated space backups

### 6. Developer Tools
- [ ] **Console Access**: Quick access to Web Inspector
- [ ] **User Agent Switcher**: Test different user agents

### 7. Customization
- [ ] **Custom CSS**: Inject CSS per site
- [ ] **User Scripts**: JavaScript injection per site
- [ ] **Search Engines**: Manage custom search providers

### 8. Performance
- [ ] **Tab Lazy Loading**: Load tabs only when viewed
- [ ] **Memory Limits**: Set memory caps per tab
- [ ] **Background Tab Throttling**: Reduce resource usage
- [ ] **Preload Predictions**: Preload likely next pages
- [ ] **Cache Management**: Manual cache control

### 10. Collaboration
- [ ] **Share Spaces**: Export space as shareable link
- [ ] **Tab Sharing**: Quick share current tab
- [ ] **Collaborative Spaces**: Real-time shared spaces
- [ ] **Comments**: Add notes/comments to tabs

## 🏗️ Architecture Improvements

### Core Infrastructure
- [ ] **Tab Virtualization**: Efficient rendering of large tab counts
- [ ] **Worker Threads**: Offload heavy operations
- [ ] **Database Optimization**: Faster queries for history/bookmarks
- [ ] **Lazy Data Loading**: Load data only when needed
- [ ] **Error Boundaries**: Graceful error handling

### Testing & Quality
- [ ] **Unit Tests**: Core logic coverage
- [ ] **UI Tests**: Automated UI testing
- [ ] **Performance Monitoring**: Track metrics
- [ ] **Crash Reporting**: Automated crash analysis

## 📱 Platform Features

### macOS Integration
- [ ] **Handoff**: Continue browsing on iOS
- [ ] **Shortcuts**: Integrate with macOS Shortcuts
- [ ] **Share Sheet**: Quick sharing to apps
- [ ] **Notification Center**: Tab notifications
- [ ] **Spotlight**: Search tabs from Spotlight

### Visual Polish
- [ ] **SF Symbols**: Use latest SF Symbols
- [ ] **Animations**: More fluid transitions
- [ ] **Haptics**: Feedback on trackpad
- [ ] **Glass Effects**: More Liquid Glass inspired by the sample code

## Technical Debt

- [ ] Refactor WebEngine for better modularity
- [ ] Improve SwiftData migration strategy
- [ ] Add comprehensive error handling
- [ ] Document public APIs
- [ ] Performance profiling and optimization