import Foundation
import WebKit

class AdBlockerService {
    static let shared = AdBlockerService()
    
    private let ruleListIdentifier = "ContentBlockerRules"
    private(set) var contentRuleList: WKContentRuleList?
    
    private init() {
        loadRules()
    }
    
    func loadRules() {
        WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: ruleListIdentifier) { [weak self] ruleList, error in
            if let ruleList = ruleList {
                print("AdBlocker: Loaded existing rules")
                self?.contentRuleList = ruleList
            } else {
                print("AdBlocker: No existing rules found, compiling default list...")
                self?.compileDefaultRules()
            }
        }
    }
    
    private func compileDefaultRules() {
        // Basic ad blocking rules (JSON format compatible with WebKit)
        // This is a small subset for demonstration. In a real app, you'd fetch EasyList.
        let rules = """
        [
            {
                "trigger": {
                    "url-filter": ".*",
                    "if-domain": ["*"]
                },
                "action": {
                    "type": "css-display-none",
                    "selector": ".ad, .ads, .advertisement, [id^='google_ads'], [id^='div-gpt-ad']"
                }
            },
            {
                "trigger": {
                    "url-filter": "doubleclick.net"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": "googlesyndication.com"
                },
                "action": {
                    "type": "block"
                }
            }
        ]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: ruleListIdentifier,
            encodedContentRuleList: rules
        ) { [weak self] ruleList, error in
            if let error = error {
                print("AdBlocker: Compilation failed: \(error.localizedDescription)")
                return
            }
            
            if let ruleList = ruleList {
                print("AdBlocker: Rules compiled successfully")
                self?.contentRuleList = ruleList
            }
        }
    }
    
    func refreshRules() {
        // Placeholder for fetching updated rules from a remote source
        compileDefaultRules()
    }
}
