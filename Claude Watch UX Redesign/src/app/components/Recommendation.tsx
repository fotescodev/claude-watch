import { Card } from '@/app/components/ui/card';
import { Badge } from '@/app/components/ui/badge';
import { Check, Sparkles, Zap, Eye, Accessibility, Watch, Crown, Bell, Layers } from 'lucide-react';

export function Recommendation() {
  return (
    <div className="space-y-6">
      {/* Executive Summary */}
      <Card className="bg-gradient-to-br from-orange-500/10 to-amber-500/5 border-orange-500/30 p-8">
        <div className="flex items-start gap-4">
          <div className="bg-orange-500 p-3 rounded-xl">
            <Watch className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1">
            <h2 className="text-2xl font-bold text-white mb-2">Design Direction: watchOS-First Approach</h2>
            <p className="text-orange-200/90 text-lg mb-4">
              Embrace watchOS 26 platform patterns—complications-first, glanceable interactions, Digital Crown navigation, 
              and Always On display optimization. This isn't a terminal app on a watch; it's a purpose-built watchOS experience 
              for developers who need instant code approval.
            </p>
            <div className="flex flex-wrap gap-2">
              <Badge className="bg-orange-500 text-white">watchOS 26 native</Badge>
              <Badge className="bg-orange-500/20 text-orange-300 border-orange-500/30" variant="outline">Complications-first</Badge>
              <Badge className="bg-orange-500/20 text-orange-300 border-orange-500/30" variant="outline">Glanceable</Badge>
              <Badge className="bg-orange-500/20 text-orange-300 border-orange-500/30" variant="outline">Always On ready</Badge>
            </div>
          </div>
        </div>
      </Card>

      {/* watchOS Platform Integration */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <div className="flex items-center gap-3 mb-6">
          <Layers className="w-6 h-6 text-orange-500" />
          <h3 className="text-2xl font-bold text-white">watchOS Platform Integration</h3>
        </div>
        <p className="text-neutral-400 mb-6">
          Claude Watch leverages every key watchOS capability to optimize the approval workflow. 
          Most interactions happen via complications and notifications—the app itself is for edge cases.
        </p>

        <div className="grid md:grid-cols-2 gap-4">
          <div className="bg-gradient-to-br from-orange-500/10 to-orange-500/5 border border-orange-500/30 rounded-xl p-5">
            <div className="flex items-start gap-3 mb-3">
              <div className="bg-orange-500/20 p-2 rounded-lg">
                <Bell className="w-5 h-5 text-orange-400" />
              </div>
              <div className="flex-1">
                <div className="text-white font-bold mb-1">1. Notifications (Primary Path)</div>
                <div className="text-orange-300/80 text-sm mb-2">85% of approvals happen here</div>
              </div>
            </div>
            <ul className="space-y-1.5 text-sm text-neutral-300 ml-11">
              <li>• Short Look: Instant recognition in 0.5s</li>
              <li>• Long Look: Approve/Reject in 1 tap (2-3s total)</li>
              <li>• Haptic feedback confirms action instantly</li>
              <li>• Works from any wrist raise, no app launch</li>
            </ul>
          </div>

          <div className="bg-gradient-to-br from-blue-500/10 to-blue-500/5 border border-blue-500/30 rounded-xl p-5">
            <div className="flex items-start gap-3 mb-3">
              <div className="bg-blue-500/20 p-2 rounded-lg">
                <Watch className="w-5 h-5 text-blue-400" />
              </div>
              <div className="flex-1">
                <div className="text-white font-bold mb-1">2. Complications (Always Visible)</div>
                <div className="text-blue-300/80 text-sm mb-2">Persistent awareness of state</div>
              </div>
            </div>
            <ul className="space-y-1.5 text-sm text-neutral-300 ml-11">
              <li>• Always On display shows pending count</li>
              <li>• Circular: Status icon + count badge</li>
              <li>• Rectangular: "3 pending" with pulse</li>
              <li>• Tap opens directly to action queue</li>
            </ul>
          </div>

          <div className="bg-gradient-to-br from-purple-500/10 to-purple-500/5 border border-purple-500/30 rounded-xl p-5">
            <div className="flex items-start gap-3 mb-3">
              <div className="bg-purple-500/20 p-2 rounded-lg">
                <Crown className="w-5 h-5 text-purple-400" />
              </div>
              <div className="flex-1">
                <div className="text-white font-bold mb-1">3. App (Detail & Batch Actions)</div>
                <div className="text-purple-300/80 text-sm mb-2">For queue management</div>
              </div>
            </div>
            <ul className="space-y-1.5 text-sm text-neutral-300 ml-11">
              <li>• Single-screen: no hierarchy to navigate</li>
              <li>• Digital Crown scrolls pending queue</li>
              <li>• "Approve All" for batch operations</li>
              <li>• View full file paths and details</li>
            </ul>
          </div>

          <div className="bg-gradient-to-br from-green-500/10 to-green-500/5 border border-green-500/30 rounded-xl p-5">
            <div className="flex items-start gap-3 mb-3">
              <div className="bg-green-500/20 p-2 rounded-lg">
                <Zap className="w-5 h-5 text-green-400" />
              </div>
              <div className="flex-1">
                <div className="text-white font-bold mb-1">4. Action Button (Optional)</div>
                <div className="text-green-300/80 text-sm mb-2">Instant approval shortcut</div>
              </div>
            </div>
            <ul className="space-y-1.5 text-sm text-neutral-300 ml-11">
              <li>• Configure: "Approve next action"</li>
              <li>• No screen glance required</li>
              <li>• Haptic confirmation of approval</li>
              <li>• For trusted coding sessions</li>
            </ul>
          </div>
        </div>
      </Card>

      {/* Rationale */}
      <div className="grid md:grid-cols-2 gap-6">
        <Card className="bg-neutral-900/50 border-neutral-800 p-6">
          <div className="flex items-center gap-3 mb-4">
            <Zap className="w-5 h-5 text-orange-500" />
            <h3 className="text-xl font-semibold text-white">Why Platform-Native Wins</h3>
          </div>
          <ul className="space-y-3 text-neutral-300">
            <li className="flex items-start gap-2">
              <Check className="w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">Glanceable by default:</strong> watchOS patterns optimized for &lt;1 second comprehension</span>
            </li>
            <li className="flex items-start gap-2">
              <Check className="w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">Always On optimization:</strong> Complications visible without wrist raise</span>
            </li>
            <li className="flex items-start gap-2">
              <Check className="w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">Shallow hierarchy:</strong> Single-screen app matches watchOS best practices</span>
            </li>
            <li className="flex items-start gap-2">
              <Check className="w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">Notifications-first:</strong> Aligns with how people actually use watches</span>
            </li>
            <li className="flex items-start gap-2">
              <Check className="w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">Digital Crown ready:</strong> Natural vertical scrolling through queue</span>
            </li>
          </ul>
        </Card>

        <Card className="bg-neutral-900/50 border-neutral-800 p-6">
          <div className="flex items-center gap-3 mb-4">
            <Accessibility className="w-5 h-5 text-orange-500" />
            <h3 className="text-xl font-semibold text-white">CRT Aesthetic Issues Solved</h3>
          </div>
          <ul className="space-y-3 text-neutral-300">
            <li className="flex items-start gap-2">
              <div className="w-4 h-4 bg-red-500/20 border border-red-500 rounded mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">6pt fonts:</strong> Now 13pt minimum (Dynamic Type compatible)</span>
            </li>
            <li className="flex items-start gap-2">
              <div className="w-4 h-4 bg-red-500/20 border border-red-500 rounded mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">Poor contrast:</strong> WCAG AA compliant on Always On display</span>
            </li>
            <li className="flex items-start gap-2">
              <div className="w-4 h-4 bg-red-500/20 border border-red-500 rounded mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">Glow effects:</strong> Replaced with watchOS materials and depth</span>
            </li>
            <li className="flex items-start gap-2">
              <div className="w-4 h-4 bg-red-500/20 border border-red-500 rounded mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">No empty states:</strong> Complete state design for all scenarios</span>
            </li>
            <li className="flex items-start gap-2">
              <div className="w-4 h-4 bg-red-500/20 border border-red-500 rounded mt-0.5 flex-shrink-0" />
              <span><strong className="text-white">Against watchOS HIG:</strong> Now follows platform conventions</span>
            </li>
          </ul>
        </Card>
      </div>

      {/* Terminal Accents Preserved */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <div className="flex items-center gap-3 mb-4">
          <Eye className="w-5 h-5 text-orange-500" />
          <h3 className="text-xl font-semibold text-white">Claude Identity Through Subtle Accents</h3>
        </div>
        <p className="text-neutral-400 mb-4">
          The terminal aesthetic becomes accent, not foundation—preserving brand while prioritizing usability.
        </p>
        <div className="grid md:grid-cols-3 gap-4">
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <div className="text-orange-400 font-mono text-sm mb-2">→ Orange Accent</div>
            <p className="text-neutral-400 text-sm">#FF9500 as primary color references amber phosphor without compromising readability</p>
          </div>
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <div className="text-orange-400 font-mono text-sm mb-2">→ Monospace IDs</div>
            <p className="text-neutral-400 text-sm">SF Mono (11pt+) for file paths and action codes maintains technical feel</p>
          </div>
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <div className="text-orange-400 font-mono text-sm mb-2">→ Pulse Animation</div>
            <p className="text-neutral-400 text-sm">Subtle glow on pending states (Reduce Motion aware)</p>
          </div>
        </div>
      </Card>

      {/* Design Principles */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h3 className="text-xl font-semibold text-white mb-4">Core Design Principles (watchOS 26 Aligned)</h3>
        <div className="grid md:grid-cols-2 gap-x-8 gap-y-4">
          <div>
            <div className="text-orange-400 font-semibold mb-1">1. Glanceable First (watchOS HIG)</div>
            <p className="text-neutral-400 text-sm">Every screen answers "what action?" in &lt;1s via Always On display</p>
          </div>
          <div>
            <div className="text-orange-400 font-semibold mb-1">2. Complications-Driven</div>
            <p className="text-neutral-400 text-sm">Primary interface is watch face—app is secondary detail view</p>
          </div>
          <div>
            <div className="text-orange-400 font-semibold mb-1">3. Single-Screen Hierarchy</div>
            <p className="text-neutral-400 text-sm">No navigation depth—Digital Crown for vertical scrolling only</p>
          </div>
          <div>
            <div className="text-orange-400 font-semibold mb-1">4. Notification-Optimized</div>
            <p className="text-neutral-400 text-sm">Long Look provides full approval flow without app launch</p>
          </div>
          <div>
            <div className="text-orange-400 font-semibold mb-1">5. Contextual Haptics</div>
            <p className="text-neutral-400 text-sm">Success/warning/error patterns provide eyes-free confirmation</p>
          </div>
          <div>
            <div className="text-orange-400 font-semibold mb-1">6. Background Materials</div>
            <p className="text-neutral-400 text-sm">Depth via translucent layers, not decorative effects</p>
          </div>
        </div>
      </Card>

      {/* Interaction Flow */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h3 className="text-xl font-semibold text-white mb-4">Typical User Flow (Sub-3s)</h3>
        <div className="relative">
          <div className="absolute left-8 top-8 bottom-8 w-0.5 bg-gradient-to-b from-orange-500 via-orange-400 to-green-500"></div>
          <div className="space-y-6">
            <div className="flex gap-4">
              <div className="bg-orange-500 text-white w-16 h-16 rounded-full flex items-center justify-center font-bold text-lg flex-shrink-0 shadow-lg relative z-10">
                0s
              </div>
              <div className="flex-1 pt-3">
                <div className="text-white font-bold mb-1">Wrist Raise</div>
                <div className="text-neutral-400 text-sm">Complication shows "3 pending" with orange pulse on Always On display</div>
              </div>
            </div>
            <div className="flex gap-4">
              <div className="bg-orange-400 text-white w-16 h-16 rounded-full flex items-center justify-center font-bold text-lg flex-shrink-0 shadow-lg relative z-10">
                0.5s
              </div>
              <div className="flex-1 pt-3">
                <div className="text-white font-bold mb-1">Notification Glance</div>
                <div className="text-neutral-400 text-sm">Short Look: "Approve code edit? • Edit App.tsx"</div>
              </div>
            </div>
            <div className="flex gap-4">
              <div className="bg-orange-300 text-white w-16 h-16 rounded-full flex items-center justify-center font-bold text-lg flex-shrink-0 shadow-lg relative z-10">
                1.5s
              </div>
              <div className="flex-1 pt-3">
                <div className="text-white font-bold mb-1">Long Look Expands</div>
                <div className="text-neutral-400 text-sm">Full action card with green "Approve" / red "Reject" buttons visible</div>
              </div>
            </div>
            <div className="flex gap-4">
              <div className="bg-green-500 text-white w-16 h-16 rounded-full flex items-center justify-center font-bold text-lg flex-shrink-0 shadow-lg relative z-10">
                2.5s
              </div>
              <div className="flex-1 pt-3">
                <div className="text-white font-bold mb-1">Tap Approve</div>
                <div className="text-neutral-400 text-sm">Haptic success pattern, checkmark appears, notification dismisses. Done.</div>
              </div>
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}