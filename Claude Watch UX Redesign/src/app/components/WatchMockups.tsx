import { Card } from '@/app/components/ui/card';
import { Check, X, Activity, FileCode, WifiOff, Inbox, Zap, AlertCircle, Settings } from 'lucide-react';
import { useState } from 'react';

export function WatchMockups() {
  const [activeScreen, setActiveScreen] = useState<'main' | 'pending' | 'empty' | 'offline'>('main');

  return (
    <div className="space-y-6">
      {/* Reference Image - placeholder for Figma export */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-4">Design Reference</h2>
        <p className="text-neutral-400 mb-4">Polished watchOS interface optimized for glanceability</p>
        <div className="max-w-xl mx-auto bg-neutral-800 rounded-2xl h-64 flex items-center justify-center">
          <span className="text-neutral-500">Figma design reference image</span>
        </div>
      </Card>

      {/* Screen Selector */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-4">Interactive Watch Screens</h2>
        <p className="text-neutral-400 mb-4">Click to switch between different app states and Always On display</p>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setActiveScreen('main')}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              activeScreen === 'main'
                ? 'bg-orange-500 text-white'
                : 'bg-neutral-800 text-neutral-300 hover:bg-neutral-700'
            }`}
          >
            Main View (Running)
          </button>
          <button
            onClick={() => setActiveScreen('pending')}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              activeScreen === 'pending'
                ? 'bg-orange-500 text-white'
                : 'bg-neutral-800 text-neutral-300 hover:bg-neutral-700'
            }`}
          >
            Pending Actions
          </button>
          <button
            onClick={() => setActiveScreen('empty')}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              activeScreen === 'empty'
                ? 'bg-orange-500 text-white'
                : 'bg-neutral-800 text-neutral-300 hover:bg-neutral-700'
            }`}
          >
            Empty State
          </button>
          <button
            onClick={() => setActiveScreen('offline')}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              activeScreen === 'offline'
                ? 'bg-orange-500 text-white'
                : 'bg-neutral-800 text-neutral-300 hover:bg-neutral-700'
            }`}
          >
            Offline State
          </button>
        </div>
      </Card>

      {/* Watch Display */}
      <div className="flex justify-center">
        <div className="relative">
          {/* Watch Frame - 44mm */}
          <div className="w-[396px] h-[484px] bg-gradient-to-br from-neutral-700 via-neutral-800 to-neutral-900 rounded-[80px] shadow-2xl p-3 border-[12px] border-neutral-950">
            {/* Screen */}
            <div className="w-full h-full bg-black rounded-[64px] overflow-hidden relative shadow-inner">
              {/* Main View - Running */}
              {activeScreen === 'main' && (
                <div className="h-full flex flex-col items-center justify-center p-6">
                  {/* Action Card - Polished Design */}
                  <div className="w-full max-w-[320px] bg-gradient-to-b from-neutral-800/80 to-neutral-900/80 backdrop-blur rounded-[32px] p-6 mb-5 shadow-xl">
                    <div className="flex items-start gap-4 mb-4">
                      <div className="bg-gradient-to-br from-orange-600 to-orange-700 p-4 rounded-[20px] shadow-lg">
                        <FileCode className="w-8 h-8 text-orange-100" strokeWidth={2.5} />
                      </div>
                      <div className="flex-1 min-w-0 pt-1">
                        <div className="text-white text-[22px] font-bold mb-1.5 leading-tight tracking-tight">
                          Edit App.tsx
                        </div>
                        <div className="text-neutral-400 text-[13px] font-mono tracking-tight">
                          src/app/App.tsx
                        </div>
                      </div>
                    </div>
                    <div className="text-neutral-500 text-[13px] font-medium">
                      2 min ago
                    </div>
                  </div>

                  {/* Action Buttons - Polished */}
                  <div className="w-full max-w-[320px] grid grid-cols-2 gap-3">
                    <button className="bg-gradient-to-b from-red-500 to-red-600 text-white font-bold py-[18px] rounded-full text-[17px] flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg hover:shadow-xl">
                      <X className="w-5 h-5" strokeWidth={3} />
                      Reject
                    </button>
                    <button className="bg-gradient-to-b from-green-500 to-green-600 text-white font-bold py-[18px] rounded-full text-[17px] flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg hover:shadow-xl">
                      <Check className="w-5 h-5" strokeWidth={3} />
                      Approve
                    </button>
                  </div>
                </div>
              )}

              {/* Pending Queue View */}
              {activeScreen === 'pending' && (
                <div className="h-full flex flex-col p-5">
                  {/* Header */}
                  <div className="flex items-center justify-between mb-5 px-1">
                    <div className="flex items-center gap-2.5">
                      <div className="relative">
                        <Activity className="w-7 h-7 text-orange-400" strokeWidth={2.5} />
                        <div className="absolute -top-1.5 -right-1.5 bg-gradient-to-br from-orange-500 to-orange-600 text-white text-[11px] font-bold rounded-full w-5 h-5 flex items-center justify-center shadow-lg">
                          3
                        </div>
                      </div>
                      <span className="text-white text-[28px] font-bold tracking-tight">Pending</span>
                    </div>
                  </div>

                  {/* Scrollable Queue */}
                  <div className="flex-1 overflow-y-auto space-y-3 px-1">
                    <div className="bg-gradient-to-b from-neutral-800/70 to-neutral-900/70 backdrop-blur rounded-[24px] p-4 shadow-lg">
                      <div className="flex items-start gap-3">
                        <div className="bg-gradient-to-br from-orange-600 to-orange-700 p-2.5 rounded-[14px] shadow-md flex-shrink-0">
                          <FileCode className="w-5 h-5 text-orange-100" strokeWidth={2.5} />
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="text-white text-[16px] font-bold leading-tight mb-1">
                            Edit dashboard.tsx
                          </div>
                          <div className="text-neutral-500 text-[11px] font-medium">2 min ago</div>
                        </div>
                      </div>
                    </div>

                    <div className="bg-gradient-to-b from-neutral-800/70 to-neutral-900/70 backdrop-blur rounded-[24px] p-4 shadow-lg">
                      <div className="flex items-start gap-3">
                        <div className="bg-gradient-to-br from-blue-600 to-blue-700 p-2.5 rounded-[14px] shadow-md flex-shrink-0">
                          <FileCode className="w-5 h-5 text-blue-100" strokeWidth={2.5} />
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="text-white text-[16px] font-bold leading-tight mb-1">
                            Create UserCard.tsx
                          </div>
                          <div className="text-neutral-500 text-[11px] font-medium">5 min ago</div>
                        </div>
                      </div>
                    </div>

                    <div className="bg-gradient-to-b from-neutral-800/70 to-neutral-900/70 backdrop-blur rounded-[24px] p-4 shadow-lg">
                      <div className="flex items-start gap-3">
                        <div className="bg-gradient-to-br from-purple-600 to-purple-700 p-2.5 rounded-[14px] shadow-md flex-shrink-0">
                          <FileCode className="w-5 h-5 text-purple-100" strokeWidth={2.5} />
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="text-white text-[16px] font-bold leading-tight mb-1">
                            Update styles.css
                          </div>
                          <div className="text-neutral-500 text-[11px] font-medium">8 min ago</div>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Approve All Button */}
                  <button className="bg-gradient-to-b from-green-500 to-green-600 text-white font-bold py-[18px] rounded-full text-[17px] mt-5 active:scale-95 transition-all shadow-lg">
                    Approve All (3)
                  </button>
                </div>
              )}

              {/* Empty State */}
              {activeScreen === 'empty' && (
                <div className="h-full flex flex-col items-center justify-center p-6">
                  <div className="bg-gradient-to-b from-neutral-800/50 to-neutral-900/50 backdrop-blur w-28 h-28 rounded-full flex items-center justify-center mb-8 shadow-xl">
                    <Inbox className="w-14 h-14 text-neutral-600" strokeWidth={2} />
                  </div>
                  <div className="text-white text-[28px] font-bold mb-3 text-center tracking-tight">
                    All Clear
                  </div>
                  <div className="text-neutral-400 text-[15px] text-center max-w-[240px] leading-relaxed">
                    No pending actions. You're all caught up!
                  </div>
                  <div className="mt-10 flex items-center gap-2.5 bg-neutral-900/50 px-4 py-2 rounded-full">
                    <div className="w-2 h-2 rounded-full bg-green-500 shadow-lg shadow-green-500/50"></div>
                    <span className="text-neutral-400 text-[13px] font-medium">Connected</span>
                  </div>
                </div>
              )}

              {/* Offline State */}
              {activeScreen === 'offline' && (
                <div className="h-full flex flex-col items-center justify-center p-6">
                  <div className="bg-gradient-to-b from-neutral-800/50 to-neutral-900/50 backdrop-blur w-28 h-28 rounded-full flex items-center justify-center mb-8 shadow-xl">
                    <WifiOff className="w-14 h-14 text-neutral-600" strokeWidth={2} />
                  </div>
                  <div className="text-white text-[28px] font-bold mb-3 text-center tracking-tight">
                    Offline
                  </div>
                  <div className="text-neutral-400 text-[15px] text-center max-w-[240px] mb-8 leading-relaxed">
                    Can't connect to Claude. Reconnecting...
                  </div>
                  <button className="bg-gradient-to-b from-blue-500 to-blue-600 text-white font-bold py-4 px-8 rounded-full text-[16px] active:scale-95 transition-all shadow-lg">
                    Retry Connection
                  </button>
                  <div className="mt-10">
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-neutral-600 animate-pulse shadow-lg"></div>
                      <div className="w-2 h-2 rounded-full bg-neutral-600 animate-pulse shadow-lg" style={{ animationDelay: '0.2s' }}></div>
                      <div className="w-2 h-2 rounded-full bg-neutral-600 animate-pulse shadow-lg" style={{ animationDelay: '0.4s' }}></div>
                    </div>
                  </div>
                </div>
              )}

              {/* Digital Crown Indicator */}
              <div className="absolute bottom-5 left-1/2 -translate-x-1/2 w-24 h-1.5 bg-white/10 rounded-full"></div>
            </div>
          </div>

          {/* Digital Crown */}
          <div className="absolute right-0 top-24 w-8 h-16 bg-gradient-to-r from-neutral-700 to-neutral-800 rounded-l-xl border-l-2 border-y-2 border-neutral-950 shadow-lg"></div>
          
          {/* Side Button */}
          <div className="absolute right-0 top-48 w-6 h-12 bg-gradient-to-r from-neutral-700 to-neutral-800 rounded-l-lg border-l-2 border-y-2 border-neutral-950 shadow-lg"></div>
        </div>
      </div>

      {/* Screen Annotations */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h3 className="text-xl font-semibold text-white mb-4">Design Notes</h3>
        <div className="grid md:grid-cols-2 gap-4">
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <div className="text-orange-400 font-semibold mb-2">Touch Target Compliance</div>
            <p className="text-neutral-400 text-sm">
              All buttons meet 44pt × 44pt minimum. Approve/Reject buttons are 48pt tall for easier tapping 
              in critical moments.
            </p>
          </div>
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <div className="text-orange-400 font-semibold mb-2">Glanceability Test</div>
            <p className="text-neutral-400 text-sm">
              Main view answers "What action?" and "Approve or reject?" in under 1 second. 
              Icon, title, and buttons visible without scrolling.
            </p>
          </div>
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <div className="text-orange-400 font-semibold mb-2">Progressive Disclosure</div>
            <p className="text-neutral-400 text-sm">
              Pending queue shows compact cards. Tap any card to see full details and individual approve/reject.
              Approve All for batch operations.
            </p>
          </div>
          <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
            <div className="text-orange-400 font-semibold mb-2">Error Recovery</div>
            <p className="text-neutral-400 text-sm">
              Offline state auto-retries connection. Manual retry available. 
              Actions queued locally until connection restored.
            </p>
          </div>
        </div>
      </Card>

      {/* Additional Screens */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h3 className="text-xl font-semibold text-white mb-4">Additional UI Patterns</h3>
        
        <div className="grid md:grid-cols-3 gap-4">
          {/* Success Confirmation */}
          <div className="bg-black rounded-2xl p-6">
            <div className="text-center">
              <div className="w-20 h-20 bg-green-500/20 rounded-full mx-auto mb-4 flex items-center justify-center">
                <Check className="w-10 h-10 text-green-400" />
              </div>
              <div className="text-white font-bold text-lg mb-1">Approved</div>
              <div className="text-neutral-500 text-xs">Edit dashboard.tsx</div>
            </div>
          </div>

          {/* Rejection Confirmation */}
          <div className="bg-black rounded-2xl p-6">
            <div className="text-center">
              <div className="w-20 h-20 bg-red-500/20 rounded-full mx-auto mb-4 flex items-center justify-center">
                <X className="w-10 h-10 text-red-400" />
              </div>
              <div className="text-white font-bold text-lg mb-1">Rejected</div>
              <div className="text-neutral-500 text-xs">Create UserCard.tsx</div>
            </div>
          </div>

          {/* Error Alert */}
          <div className="bg-black rounded-2xl p-6">
            <div className="text-center">
              <div className="w-20 h-20 bg-red-500/20 rounded-full mx-auto mb-4 flex items-center justify-center">
                <AlertCircle className="w-10 h-10 text-red-400" />
              </div>
              <div className="text-white font-bold text-lg mb-1">Error</div>
              <div className="text-neutral-500 text-xs">Action failed to send</div>
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}