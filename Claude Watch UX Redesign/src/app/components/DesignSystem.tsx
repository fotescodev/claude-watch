import { Card } from '@/app/components/ui/card';
import { Badge } from '@/app/components/ui/badge';

export function DesignSystem() {
  return (
    <div className="space-y-6">
      {/* Color Palette */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-6">Color Palette</h2>
        
        {/* Primary & Accent */}
        <div className="mb-8">
          <h3 className="text-lg font-semibold text-white mb-4">Primary & Accent</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <div className="bg-[#FF9500] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#FF9500</div>
              <div className="text-xs text-neutral-500">Orange (Primary)</div>
            </div>
            <div>
              <div className="bg-[#FFB340] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#FFB340</div>
              <div className="text-xs text-neutral-500">Orange Light</div>
            </div>
            <div>
              <div className="bg-[#CC7700] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#CC7700</div>
              <div className="text-xs text-neutral-500">Orange Dark</div>
            </div>
            <div>
              <div className="bg-[#FFCC80] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#FFCC80</div>
              <div className="text-xs text-neutral-500">Amber Glow</div>
            </div>
          </div>
        </div>

        {/* Semantic Colors */}
        <div className="mb-8">
          <h3 className="text-lg font-semibold text-white mb-4">Semantic Colors</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <div className="bg-[#34C759] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#34C759</div>
              <div className="text-xs text-neutral-500">Success (Approve)</div>
            </div>
            <div>
              <div className="bg-[#FF3B30] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#FF3B30</div>
              <div className="text-xs text-neutral-500">Danger (Reject)</div>
            </div>
            <div>
              <div className="bg-[#FF9500] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#FF9500</div>
              <div className="text-xs text-neutral-500">Warning</div>
            </div>
            <div>
              <div className="bg-[#007AFF] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#007AFF</div>
              <div className="text-xs text-neutral-500">Info</div>
            </div>
          </div>
        </div>

        {/* Surface Colors */}
        <div>
          <h3 className="text-lg font-semibold text-white mb-4">Surface Colors</h3>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
            <div>
              <div className="bg-black h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#000000</div>
              <div className="text-xs text-neutral-500">Background</div>
            </div>
            <div>
              <div className="bg-[#1C1C1E] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#1C1C1E</div>
              <div className="text-xs text-neutral-500">Surface 1</div>
            </div>
            <div>
              <div className="bg-[#2C2C2E] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#2C2C2E</div>
              <div className="text-xs text-neutral-500">Surface 2</div>
            </div>
            <div>
              <div className="bg-[#3A3A3C] h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#3A3A3C</div>
              <div className="text-xs text-neutral-500">Surface 3</div>
            </div>
            <div>
              <div className="bg-white h-24 rounded-lg mb-2 border border-neutral-700"></div>
              <div className="text-sm font-mono text-neutral-300">#FFFFFF</div>
              <div className="text-xs text-neutral-500">Text Primary</div>
            </div>
          </div>
        </div>

        {/* Contrast Compliance */}
        <div className="mt-6 bg-neutral-950 border border-neutral-700 rounded-lg p-4">
          <div className="text-sm text-neutral-400">
            <strong className="text-white">WCAG AA Compliance:</strong> All text colors on surface backgrounds meet 4.5:1 contrast. 
            UI elements (buttons, icons) meet 3:1. Tested on 40mm–49mm displays.
          </div>
        </div>
      </Card>

      {/* Typography */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-6">Typography</h2>
        
        <div className="space-y-6">
          <div className="border-b border-neutral-700 pb-4">
            <div className="text-3xl text-white mb-2" style={{ fontFamily: 'SF Compact Display, system-ui, -apple-system' }}>
              SF Compact Display
            </div>
            <div className="text-sm text-neutral-400">Primary display font • Headlines, status, action buttons</div>
          </div>

          <div className="border-b border-neutral-700 pb-4">
            <div className="text-xl text-white mb-2" style={{ fontFamily: 'SF Compact Text, system-ui, -apple-system' }}>
              SF Compact Text
            </div>
            <div className="text-sm text-neutral-400">Body text font • Descriptions, secondary info</div>
          </div>

          <div className="border-b border-neutral-700 pb-4">
            <div className="text-base font-mono text-orange-400 mb-2">
              SF Mono
            </div>
            <div className="text-sm text-neutral-400">Monospace font • Action IDs, file paths, complications (11pt min)</div>
          </div>
        </div>

        {/* Text Styles */}
        <div className="mt-8">
          <h3 className="text-lg font-semibold text-white mb-4">Text Styles</h3>
          <div className="space-y-4 bg-neutral-950 border border-neutral-700 rounded-lg p-6">
            <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
              <div>
                <div className="text-white text-2xl font-bold">Large Title</div>
                <div className="text-neutral-500 text-sm">SF Compact Display • 28pt • Bold</div>
              </div>
              <Badge variant="outline" className="text-xs">Status header</Badge>
            </div>
            
            <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
              <div>
                <div className="text-white text-xl font-semibold">Title</div>
                <div className="text-neutral-500 text-sm">SF Compact Display • 20pt • Semibold</div>
              </div>
              <Badge variant="outline" className="text-xs">Action summary</Badge>
            </div>
            
            <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
              <div>
                <div className="text-white text-base font-medium">Headline</div>
                <div className="text-neutral-500 text-sm">SF Compact Text • 15pt • Medium</div>
              </div>
              <Badge variant="outline" className="text-xs">Button labels</Badge>
            </div>
            
            <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
              <div>
                <div className="text-white text-sm">Body</div>
                <div className="text-neutral-500 text-sm">SF Compact Text • 13pt • Regular</div>
              </div>
              <Badge variant="outline" className="text-xs">Descriptions</Badge>
            </div>
            
            <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
              <div>
                <div className="text-neutral-400 text-xs">Caption</div>
                <div className="text-neutral-500 text-sm">SF Compact Text • 11pt • Regular</div>
              </div>
              <Badge variant="outline" className="text-xs">Timestamps, metadata</Badge>
            </div>
            
            <div className="flex items-center justify-between">
              <div>
                <div className="text-orange-400 font-mono text-xs">Monospace</div>
                <div className="text-neutral-500 text-sm">SF Mono • 11pt • Regular</div>
              </div>
              <Badge variant="outline" className="text-xs">Action IDs, codes</Badge>
            </div>
          </div>
        </div>

        {/* Dynamic Type */}
        <div className="mt-6 bg-neutral-950 border border-neutral-700 rounded-lg p-4">
          <div className="text-sm text-neutral-400">
            <strong className="text-white">Dynamic Type Support:</strong> All text styles scale with user's accessibility settings. 
            Minimum touch target of 44pt × 44pt maintained across all sizes. Layouts use flexible spacing.
          </div>
        </div>
      </Card>

      {/* Spacing & Layout */}
      <Card className="bg-neutral-900/50 border-neutral-800 p-6">
        <h2 className="text-2xl font-bold text-white mb-6">Spacing & Layout</h2>
        
        <div className="grid md:grid-cols-2 gap-6">
          <div>
            <h3 className="text-lg font-semibold text-white mb-4">Spacing Scale</h3>
            <div className="space-y-2">
              <div className="flex items-center gap-4">
                <div className="w-1 h-6 bg-orange-500"></div>
                <span className="text-neutral-300 font-mono text-sm">4pt • Extra tight</span>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-2 h-6 bg-orange-500"></div>
                <span className="text-neutral-300 font-mono text-sm">8pt • Tight</span>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-3 h-6 bg-orange-500"></div>
                <span className="text-neutral-300 font-mono text-sm">12pt • Base</span>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-4 h-6 bg-orange-500"></div>
                <span className="text-neutral-300 font-mono text-sm">16pt • Comfortable</span>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-6 h-6 bg-orange-500"></div>
                <span className="text-neutral-300 font-mono text-sm">24pt • Spacious</span>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold text-white mb-4">Touch Targets</h3>
            <div className="space-y-4">
              <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
                <div className="text-white font-semibold mb-1">Primary Actions</div>
                <div className="text-neutral-400 text-sm">Approve/Reject: 44pt × 44pt minimum</div>
              </div>
              <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
                <div className="text-white font-semibold mb-1">Secondary Actions</div>
                <div className="text-neutral-400 text-sm">View Details, Settings: 44pt × 44pt</div>
              </div>
              <div className="bg-neutral-950 border border-neutral-700 rounded-lg p-4">
                <div className="text-white font-semibold mb-1">Safe Area</div>
                <div className="text-neutral-400 text-sm">12pt margin from screen edges</div>
              </div>
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}
