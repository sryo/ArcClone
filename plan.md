# ArcClone - How It Works

A browser built with Swift, SwiftUI, and WebKit that reimagines web browsing with spaces and pinned tabs.

## Data Models (SwiftData)

**BrowserSpace** - A workspace containing:
- Pinned tabs (persistent apps)
- Today tabs (current browsing)
- Archived tabs (older than 12 hours)
- Name, color, and optional emoji icon

**BrowserTab** - A web page containing:
- URL, title, favicon
- Navigation state (canGoBack/canGoForward)
- Pinned status
- Folder support with children tabs
- Optional emoji icon

**HistoryEntry** - URL visit tracking with timestamps

## WebEngine (Singleton)

The `WebEngine` manages all web views:
- Keeps WKWebView instances alive per tab (cached by `tabID_contextID`)
- Handles navigation and URL updates
- Implements pinned tab behavior: clicking links in pinned tabs opens them in new Today tabs
- Updates tab metadata when pages load

## User Interface

**Main View** - `NavigationSplitView` with:
- Sidebar: Spaces selector, pinned tabs, today tabs
- Detail: Active tab's web content
- Library mode: Archived tabs, spaces overview, media, downloads

**Command Palette** - Cmd+L opens:
- URL entry and web search
- Live suggestions from open tabs and history
- Quick navigation

**Features**:
- Drag & drop tabs between pinned/today sections
- Move tabs between spaces
- Rename tabs and spaces
- Close tabs with archive history (Cmd+Shift+T to reopen)
- Back/forward navigation buttons
- Library view (Cmd+Shift+L)

## Key Behaviors

1. **Pinned tabs** act like apps - links to different domains open in new Today tabs
2. **Today tabs** auto-archive after 12 hours
3. **Web views** are cached and reused per window context
4. **Spaces** separate work/personal/project browsing
5. **Library** provides access to archived tabs and space management