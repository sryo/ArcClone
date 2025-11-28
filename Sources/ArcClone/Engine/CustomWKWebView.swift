import WebKit
import AppKit

/// Custom WKWebView subclass that adds support for right-click context menu on images and links
class CustomWKWebView: WKWebView {
    
    /// Handler for opening URL in a new window
    var openInNewWindowHandler: ((URL) -> Void)?
    
    /// Store the last click location and element info
    private var lastClickLocation: CGPoint = .zero
    private var contextLinkURL: URL?
    private var contextImageURL: URL?
    
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        lastClickLocation = convert(event.locationInWindow, from: nil)
        
        // Get element info synchronously using hit testing
        // We'll add menu items and use JavaScript on-demand when clicked
        
        // Use JavaScript to get element info at the click location
        let js = """
        (function() {
            var element = document.elementFromPoint(\(lastClickLocation.x), \(Int((window?.contentView?.bounds.height ?? 0) - lastClickLocation.y)));
            if (!element) return null;
            
            var result = {};
            
            // Check if it's a link
            var link = element.closest('a');
            if (link && link.href) {
                result.linkURL = link.href;
            }
            
            // Check if it's an image
            if (element.tagName === 'IMG' && element.src) {
                result.imageURL = element.src;
            }
            
            return result;
        })();
        """
        
        // We need to evaluate this synchronously, but WKWebView doesn't have a sync API
        // So we'll add the menu items optimistically and check when clicked
        // First, let's try to add menu items that will work for most cases
        
        // Add menu items at the top
        var insertIndex = 0
        
        let openLinkItem = NSMenuItem(
            title: "Open Link in New Window",
            action: #selector(openLinkInNewWindow(_:)),
            keyEquivalent: ""
        )
        openLinkItem.target = self
        menu.insertItem(openLinkItem, at: insertIndex)
        insertIndex += 1
        
        let openImageItem = NSMenuItem(
            title: "Open Image in New Window",
            action: #selector(openImageInNewWindow(_:)),
            keyEquivalent: ""
        )
        openImageItem.target = self
        menu.insertItem(openImageItem, at: insertIndex)
        insertIndex += 1
        
        menu.insertItem(NSMenuItem.separator(), at: insertIndex)
        
        // Evaluate JavaScript to get actual element info
        evaluateJavaScript(js) { [weak self, weak openLinkItem, weak openImageItem] result, error in
            guard let self = self,
                  let dict = result as? [String: String] else {
                // If we can't get info, hide both items
                DispatchQueue.main.async {
                    openLinkItem?.isHidden = true
                    openImageItem?.isHidden = true
                }
                return
            }
            
            var linkURL: URL?
            var imageURL: URL?
            
            if let urlString = dict["linkURL"], let url = URL(string: urlString) {
                linkURL = url
            }
            
            if let urlString = dict["imageURL"], let url = URL(string: urlString) {
                imageURL = url
            }
            
            self.contextLinkURL = linkURL
            self.contextImageURL = imageURL
            
            // Update menu items visibility on main thread
            DispatchQueue.main.async {
                if linkURL != nil, imageURL == nil {
                    // Only link, not an image
                    openLinkItem?.isHidden = false
                    openImageItem?.isHidden = true
                } else if let _ = imageURL {
                    // Image (possibly a linked image)
                    openImageItem?.isHidden = false
                    openLinkItem?.isHidden = imageURL != nil && linkURL != nil ? true : linkURL != nil
                } else {
                    // Neither link nor image
                    openLinkItem?.isHidden = true
                    openImageItem?.isHidden = true
                }
            }
        }
        
        super.willOpenMenu(menu, with: event)
    }
    
    @objc private func openLinkInNewWindow(_ sender: NSMenuItem) {
        if let url = contextLinkURL {
            openInNewWindowHandler?(url)
        }
    }
    
    @objc private func openImageInNewWindow(_ sender: NSMenuItem) {
        if let url = contextImageURL {
            openInNewWindowHandler?(url)
        }
    }
}

