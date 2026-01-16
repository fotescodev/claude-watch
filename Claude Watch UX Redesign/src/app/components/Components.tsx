import { Card } from '@/app/components/ui/card';
import { Badge } from '@/app/components/ui/badge';
import { Check, X, Activity, Zap, FileCode, AlertCircle, WifiOff, Inbox } from 'lucide-react';

export function Components() {
  return (
    <div className="space-y-6">
      {/* Action Card */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-6">ActionCard Component</h2>
        <p className="text-neutral-400 mb-6">The core component for displaying pending code actions. Optimized for glanceability.</p>
        
        {/* Specs */}
        <div className="grid md:grid-cols-2 gap-6 mb-6">
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">Dimensions</h3>
            <ul className="space-y-2 text-sm text-neutral-400">
              <li>• Height: 160pt (fits 40mm screen with buttons)</li>
              <li>• Corner radius: 20pt (watchOS style)</li>
              <li>• Padding: 12pt all sides</li>
              <li>• Background: Surface 1 (#1C1C1E)</li>
            </ul>
          </div>
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">Content Priority</h3>
            <ol className="space-y-2 text-sm text-neutral-400">
              <li>1. <strong className="text-white">Action type icon</strong> (top-left, 24pt)</li>
              <li>2. <strong className="text-white">Action summary</strong> (Title, 20pt, 2 lines max)</li>
              <li>3. <strong className="text-white">File path</strong> (Mono, 11pt, truncated)</li>
              <li>4. <strong className="text-white">Timestamp</strong> (Caption, 11pt, relative)</li>
            </ol>
          </div>
        </div>

        {/* Visual Example */}
        <div className="bg-black rounded-2xl p-6 max-w-sm mx-auto">
          <div className="bg-gradient-to-b from-neutral-800/80 to-neutral-900/80 backdrop-blur rounded-[28px] p-5 mb-4 shadow-xl">
            <div className="flex items-start gap-3.5 mb-3">
              <div className="bg-gradient-to-br from-orange-600 to-orange-700 p-3.5 rounded-[18px] shadow-lg">
                <FileCode className="w-7 h-7 text-orange-100" strokeWidth={2.5} />
              </div>
              <div className="flex-1 min-w-0 pt-0.5">
                <div className="text-white text-lg font-bold mb-1 leading-tight tracking-tight">
                  Edit App.tsx
                </div>
                <div className="text-neutral-400 text-xs font-mono truncate">
                  src/app/App.tsx
                </div>
              </div>
            </div>
            <div className="text-neutral-500 text-xs font-medium">
              2 min ago
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2.5">
            <button className="bg-gradient-to-b from-red-500 to-red-600 text-white font-bold py-3.5 rounded-full text-sm flex items-center justify-center gap-1.5 shadow-lg">
              <X className="w-4 h-4" strokeWidth={3} />
              Reject
            </button>
            <button className="bg-gradient-to-b from-green-500 to-green-600 text-white font-bold py-3.5 rounded-full text-sm flex items-center justify-center gap-1.5 shadow-lg">
              <Check className="w-4 h-4" strokeWidth={3} />
              Approve
            </button>
          </div>
        </div>
      </Card>

      {/* Status Header */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-6">StatusHeader Component</h2>
        <p className="text-neutral-400 mb-6">Top-of-screen status indicator for main app view.</p>
        
        <div className="grid md:grid-cols-2 gap-6 mb-6">
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">States</h3>
            <ul className="space-y-2 text-sm text-neutral-400">
              <li>• <strong className="text-green-400">Idle:</strong> "Ready" + checkmark icon</li>
              <li>• <strong className="text-orange-400">Running:</strong> "Active" + pulse animation</li>
              <li>• <strong className="text-blue-400">Pending:</strong> "3 actions" + badge count</li>
              <li>• <strong className="text-red-400">Offline:</strong> "Disconnected" + WiFi off icon</li>
            </ul>
          </div>
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">Styling</h3>
            <ul className="space-y-2 text-sm text-neutral-400">
              <li>• Large Title (28pt) for main status text</li>
              <li>• Icon: 20pt, matches semantic color</li>
              <li>• Height: 44pt (allows scroll underneath)</li>
              <li>• Background: Gradient fade to black</li>
            </ul>
          </div>
        </div>

        {/* Visual Examples */}
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-black rounded-2xl p-4">
            <div className="flex items-center gap-2">
              <Activity className="w-5 h-5 text-orange-400 animate-pulse" />
              <span className="text-white text-2xl font-bold">Active</span>
            </div>
          </div>
          <div className="bg-black rounded-2xl p-4">
            <div className="flex items-center gap-2">
              <div className="relative">
                <Activity className="w-5 h-5 text-blue-400" />
                <div className="absolute -top-1 -right-1 bg-orange-500 text-white text-[10px] font-bold rounded-full w-4 h-4 flex items-center justify-center">
                  3
                </div>
              </div>
              <span className="text-white text-2xl font-bold">Pending</span>
            </div>
          </div>
        </div>
      </Card>

      {/* Complications */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-6">Complications</h2>
        <p className="text-neutral-400 mb-6">Watch face widgets showing Claude Watch status at a glance.</p>
        
        <div className="grid md:grid-cols-2 gap-6">
          {/* Circular */}
          <div>
            <h3 className="text-white font-semibold mb-4">Accessory Circular</h3>
            <div className="bg-black rounded-2xl p-6">
              <div className="flex flex-col items-center gap-4">
                {/* Idle State */}
                <div className="text-center">
                  <div className="w-20 h-20 rounded-full bg-neutral-900 border-2 border-green-500 flex items-center justify-center mb-2">
                    <Check className="w-8 h-8 text-green-400" />
                  </div>
                  <div className="text-neutral-500 text-xs">Idle</div>
                </div>
                {/* Pending State */}
                <div className="text-center">
                  <div className="w-20 h-20 rounded-full bg-neutral-900 border-2 border-orange-500 flex items-center justify-center mb-2 relative">
                    <div className="text-orange-400 font-mono text-xl font-bold">3</div>
                    <div className="absolute inset-0 rounded-full border-2 border-orange-500 animate-pulse"></div>
                  </div>
                  <div className="text-neutral-500 text-xs">3 pending</div>
                </div>
              </div>
            </div>
          </div>

          {/* Rectangular */}
          <div>
            <h3 className="text-white font-semibold mb-4">Accessory Rectangular</h3>
            <div className="bg-black rounded-2xl p-6">
              <div className="space-y-4">
                {/* Idle State */}
                <div className="bg-neutral-900 rounded-xl p-3 border border-green-500/30">
                  <div className="flex items-center gap-2">
                    <Check className="w-4 h-4 text-green-400" />
                    <div className="flex-1">
                      <div className="text-white text-xs font-semibold">Claude</div>
                      <div className="text-green-400 text-[10px] font-mono">Ready</div>
                    </div>
                  </div>
                </div>
                {/* Pending State */}
                <div className="bg-neutral-900 rounded-xl p-3 border border-orange-500/30">
                  <div className="flex items-center gap-2">
                    <div className="relative">
                      <Activity className="w-4 h-4 text-orange-400" />
                    </div>
                    <div className="flex-1">
                      <div className="text-white text-xs font-semibold">Claude</div>
                      <div className="text-orange-400 text-[10px] font-mono">3 pending</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="mt-6 bg-neutral-950 border border-neutral-700 rounded-lg p-4">
          <div className="text-sm text-neutral-400">
            <strong className="text-white">Complication States:</strong> Idle (green checkmark), Running (orange pulse), 
            Pending (count badge), Offline (gray with WiFi off). Tap complication to open app directly to action queue.
          </div>
        </div>
      </Card>

      {/* Notification Layout */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-6">Notification Layout</h2>
        <p className="text-neutral-400 mb-6">Critical path for sub-3-second approvals. Designed for minimal cognitive load.</p>
        
        <div className="grid md:grid-cols-2 gap-6 mb-6">
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">Short Look</h3>
            <p className="text-neutral-400 text-sm mb-3">Appears first, 2 seconds before expanding</p>
            <ul className="space-y-1 text-sm text-neutral-400">
              <li>• App icon + "Claude"</li>
              <li>• "Approve code edit?"</li>
              <li>• File name only (no path)</li>
            </ul>
          </div>
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">Long Look</h3>
            <p className="text-neutral-400 text-sm mb-3">Expands with action buttons</p>
            <ul className="space-y-1 text-sm text-neutral-400">
              <li>• Full action summary (2 lines)</li>
              <li>• Truncated file path</li>
              <li>• Approve (green) / Reject (red) buttons</li>
              <li>• "View Details" link (optional)</li>
            </ul>
          </div>
        </div>

        {/* Visual Example */}
        <div className="bg-black rounded-2xl p-6 max-w-sm mx-auto">
          <div className="text-center mb-5">
            <div className="bg-gradient-to-br from-orange-500 to-orange-600 w-14 h-14 rounded-full mx-auto mb-3 flex items-center justify-center shadow-lg">
              <Zap className="w-7 h-7 text-white" strokeWidth={2.5} />
            </div>
            <div className="text-neutral-400 text-[10px] font-semibold tracking-wider mb-2">CLAUDE</div>
            <div className="text-white font-bold text-[17px] mb-1.5 tracking-tight">Approve code edit?</div>
            <div className="text-neutral-300 text-[14px] mb-0.5">Edit App.tsx</div>
            <div className="text-neutral-500 text-[11px] font-mono">src/app/App.tsx</div>
          </div>
          <div className="space-y-2.5">
            <button className="w-full bg-gradient-to-b from-green-500 to-green-600 text-white font-bold py-3.5 rounded-full text-[15px] shadow-lg active:scale-95 transition-transform">
              Approve
            </button>
            <button className="w-full bg-gradient-to-b from-red-500 to-red-600 text-white font-bold py-3.5 rounded-full text-[15px] shadow-lg active:scale-95 transition-transform">
              Reject
            </button>
            <button className="w-full text-blue-400 font-semibold py-2.5 text-[13px]">
              View Details
            </button>
          </div>
        </div>
      </Card>

      {/* State Screens */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-6">State Screens</h2>
        
        <div className="grid md:grid-cols-3 gap-4">
          {/* Empty State */}
          <div className="bg-black rounded-2xl p-6 text-center">
            <div className="bg-neutral-900 w-16 h-16 rounded-full mx-auto mb-3 flex items-center justify-center">
              <Inbox className="w-8 h-8 text-neutral-600" />
            </div>
            <div className="text-white font-semibold mb-1">All Clear</div>
            <div className="text-neutral-500 text-xs">No pending actions</div>
          </div>

          {/* Offline State */}
          <div className="bg-black rounded-2xl p-6 text-center">
            <div className="bg-neutral-900 w-16 h-16 rounded-full mx-auto mb-3 flex items-center justify-center">
              <WifiOff className="w-8 h-8 text-neutral-600" />
            </div>
            <div className="text-white font-semibold mb-1">Offline</div>
            <div className="text-neutral-500 text-xs">Reconnecting...</div>
          </div>

          {/* Error State */}
          <div className="bg-black rounded-2xl p-6 text-center">
            <div className="bg-red-500/20 w-16 h-16 rounded-full mx-auto mb-3 flex items-center justify-center">
              <AlertCircle className="w-8 h-8 text-red-400" />
            </div>
            <div className="text-white font-semibold mb-1">Error</div>
            <div className="text-neutral-500 text-xs">Tap to retry</div>
          </div>
        </div>
      </Card>
    </div>
  );
}