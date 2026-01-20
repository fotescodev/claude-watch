import React, { useState, useEffect } from 'react';

// ============================================================================
// CLAUDE WATCH — UPDATED DESIGN SYSTEM (Post-Overhaul)
// Reflects all 6 phases of implementation
// ============================================================================

const ClaudeWatchUpdated = () => {
  const [activeView, setActiveView] = useState('overview');
  const [watchScreen, setWatchScreen] = useState('main-pending');
  const [selectedActions, setSelectedActions] = useState(new Set([0, 1, 2]));
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => setTick(t => t + 1), 50);
    return () => clearInterval(timer);
  }, []);

  const pulse = Math.sin(tick * 0.08) * 0.3 + 0.7;

  // ==========================================================================
  // DESIGN TOKENS — Updated with new additions
  // ==========================================================================
  const brand = {
    // Core colors (Apple HIG compliant)
    orange: '#FF9500',
    orangeLight: '#FFB340',
    orangeDark: '#CC7700',
    success: '#34C759',
    danger: '#FF3B30',
    warning: '#FF9500',
    info: '#007AFF',

    // NEW: Danger background (Phase 2)
    dangerBackground: 'rgba(255, 59, 48, 0.15)',

    // NEW: Anthropic brand references (Phase 1)
    brandDark: '#141413',
    brandLight: '#faf9f5',

    // Surfaces
    background: '#000000',
    surface1: '#1C1C1E',
    surface2: '#2C2C2E',
    surface3: '#3A3A3C',

    // Text
    textPrimary: '#FFFFFF',
    textSecondary: 'rgba(255,255,255,0.6)',
    textTertiary: 'rgba(255,255,255,0.4)',

    // NEW: Mode colors (Phase 1)
    modeNormal: '#007AFF',
    modeAutoAccept: '#FF3B30',
    modePlan: '#9b8ac4',
  };

  // ==========================================================================
  // ICONS
  // ==========================================================================
  const Icon = ({ type, size = 16, color = brand.textPrimary }) => {
    const icons = {
      settings: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <circle cx="12" cy="12" r="3"/><path d="M12 1v4M12 19v4M4.22 4.22l2.83 2.83M16.95 16.95l2.83 2.83M1 12h4M19 12h4M4.22 19.78l2.83-2.83M16.95 7.05l2.83-2.83"/>
        </svg>
      ),
      check: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5">
          <polyline points="20 6 9 17 4 12"/>
        </svg>
      ),
      x: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5">
          <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
        </svg>
      ),
      edit: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
          <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
        </svg>
      ),
      filePlus: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/>
          <line x1="12" y1="18" x2="12" y2="12"/><line x1="9" y1="15" x2="15" y2="15"/>
        </svg>
      ),
      trash: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
        </svg>
      ),
      terminal: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/>
        </svg>
      ),
      alert: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
          <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
        </svg>
      ),
      clock: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
        </svg>
      ),
      arrowLeft: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/>
        </svg>
      ),
      history: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <path d="M3 3v5h5"/><path d="M3.05 13A9 9 0 1 0 6 5.3L3 8"/><path d="M12 7v5l4 2"/>
        </svg>
      ),
      checkSquare: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
        </svg>
      ),
      square: (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
        </svg>
      ),
    };
    return icons[type] || null;
  };

  // ==========================================================================
  // NEW: DANGER INDICATOR (Phase 2)
  // ==========================================================================
  const DangerIndicator = () => (
    <div className="flex items-center gap-1">
      <Icon type="alert" size={10} color={brand.danger} />
      <span style={{ fontSize: 10, fontWeight: 600, color: brand.danger }}>Destructive</span>
    </div>
  );

  const DangerBadge = () => (
    <div
      className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full"
      style={{ background: brand.dangerBackground }}
    >
      <Icon type="alert" size={12} color={brand.danger} />
      <span style={{ fontSize: 11, fontWeight: 600, color: brand.danger }}>Destructive Action</span>
    </div>
  );

  // ==========================================================================
  // NEW: ETA DISPLAY (Phase 3)
  // ==========================================================================
  const ETADisplay = ({ eta }) => (
    <div className="flex items-center gap-1">
      <Icon type="clock" size={10} color={brand.textSecondary} />
      <span style={{ fontSize: 10, color: brand.textSecondary }}>{eta}</span>
    </div>
  );

  // ==========================================================================
  // NEW: AUTO BADGE (Phase 5)
  // ==========================================================================
  const AutoBadge = () => (
    <span
      className="px-1.5 py-0.5 rounded text-white"
      style={{ fontSize: 8, fontWeight: 500, background: brand.surface2 }}
    >
      auto
    </span>
  );

  // ==========================================================================
  // STATUS DOT
  // ==========================================================================
  const StatusDot = ({ state, size = 8, animated = true }) => {
    const colors = {
      running: brand.success,
      pending: brand.orange,
      complete: brand.info,
      error: brand.danger,
      idle: brand.textSecondary,
    };
    const color = colors[state] || brand.textSecondary;
    const shouldAnimate = animated && (state === 'running' || state === 'pending');

    return (
      <div className="relative" style={{ width: size, height: size }}>
        {shouldAnimate && (
          <div
            className="absolute inset-0 rounded-full"
            style={{
              backgroundColor: color,
              opacity: 0.4 * pulse,
              transform: `scale(${1.3 + pulse * 0.3})`,
            }}
          />
        )}
        <div className="absolute inset-0 rounded-full" style={{ backgroundColor: color }} />
      </div>
    );
  };

  // ==========================================================================
  // WATCH FRAME
  // ==========================================================================
  const WatchFrame = ({ children, scale = 1, label }) => (
    <div className="flex flex-col items-center">
      <div
        className="relative"
        style={{
          width: 170 * scale,
          height: 208 * scale,
          filter: 'drop-shadow(0 16px 32px rgba(0,0,0,0.35))',
        }}
      >
        <div className="absolute inset-0" style={{ borderRadius: 40 * scale, background: 'linear-gradient(160deg, #3a3a3a 0%, #1a1a1a 50%, #0f0f0f 100%)' }} />
        <div className="absolute" style={{ top: 7 * scale, left: 7 * scale, right: 7 * scale, bottom: 7 * scale, borderRadius: 35 * scale, background: '#000' }} />
        <div className="absolute overflow-hidden" style={{ top: 10 * scale, left: 10 * scale, right: 10 * scale, bottom: 10 * scale, borderRadius: 32 * scale, background: brand.background }}>
          {children}
        </div>
        <div className="absolute" style={{ right: -5 * scale, top: '28%', width: 6 * scale, height: 26 * scale, borderRadius: 3 * scale, background: 'linear-gradient(90deg, #444 0%, #222 100%)' }} />
        <div className="absolute" style={{ right: -4 * scale, top: '52%', width: 5 * scale, height: 14 * scale, borderRadius: 2 * scale, background: 'linear-gradient(90deg, #3a3a3a 0%, #1a1a1a 100%)' }} />
      </div>
      {label && (
        <div className="mt-3 text-xs font-medium text-center" style={{ color: brand.textSecondary }}>
          {label}
        </div>
      )}
    </div>
  );

  // ==========================================================================
  // WATCH SCREENS
  // ==========================================================================

  // Main - Single Pending (Original)
  const MainPendingScreen = () => (
    <div className="h-full flex flex-col p-2.5" style={{ fontFamily: 'system-ui' }}>
      <div className="flex justify-end mb-1.5">
        <button className="p-1 opacity-60"><Icon type="settings" size={14} color={brand.textSecondary} /></button>
      </div>

      <div className="flex items-center gap-1.5 mb-2">
        <StatusDot state="running" size={6} />
        <span className="text-xs" style={{ color: brand.success }}>Running</span>
        <span className="text-xs ml-auto" style={{ color: brand.textSecondary }}>42%</span>
      </div>

      <div className="flex-1 rounded-xl p-2.5 flex flex-col" style={{ background: brand.surface1 }}>
        <div className="flex items-center gap-1.5 mb-1">
          <Icon type="edit" size={12} color={brand.orange} />
          <span className="text-xs font-medium" style={{ color: brand.orange }}>Edit</span>
        </div>
        <div className="text-xs mb-0.5" style={{ color: brand.textPrimary, fontFamily: 'monospace' }}>src/App.tsx</div>
        <div className="text-xs flex-1" style={{ color: brand.textSecondary, fontSize: 10 }}>
          Add dark mode toggle
        </div>

        <div className="flex gap-2 mt-2">
          <button className="flex-1 py-1.5 rounded-lg text-xs font-medium flex items-center justify-center gap-1" style={{ background: brand.surface2, color: brand.textSecondary }}>
            <Icon type="x" size={10} color={brand.textSecondary} />Reject
          </button>
          <button className="flex-1 py-1.5 rounded-lg text-xs font-medium flex items-center justify-center gap-1" style={{ background: brand.success, color: brand.background }}>
            <Icon type="check" size={10} color={brand.background} />Approve
          </button>
        </div>
      </div>
    </div>
  );

  // NEW: Progress + ETA (Phase 3 - Jordan's need)
  const ProgressETAScreen = () => (
    <div className="h-full flex flex-col p-2.5" style={{ fontFamily: 'system-ui' }}>
      <div className="flex justify-end mb-1.5">
        <button className="p-1 opacity-60"><Icon type="settings" size={14} color={brand.textSecondary} /></button>
      </div>

      <div className="flex items-center gap-1.5 mb-2">
        <StatusDot state="running" size={6} />
        <span className="text-xs" style={{ color: brand.success }}>Running</span>
        <div className="flex items-center gap-1 ml-auto">
          <ETADisplay eta="~8m left" />
        </div>
      </div>

      <div className="mb-2">
        <div className="flex justify-between items-center mb-1">
          <span className="text-xs" style={{ color: brand.textPrimary }}>Database migration</span>
          <span className="text-xs font-medium" style={{ color: brand.success }}>65%</span>
        </div>
        <div className="h-1.5 rounded-full overflow-hidden" style={{ background: brand.surface2 }}>
          <div className="h-full rounded-full" style={{ width: '65%', background: brand.success }} />
        </div>
        <div className="flex justify-between mt-1">
          <span className="text-xs" style={{ color: brand.textSecondary }}>127/195 tables</span>
          <span className="text-xs" style={{ color: brand.textSecondary }}>12m elapsed</span>
        </div>
      </div>

      <div className="flex-1 rounded-xl p-3 flex flex-col items-center justify-center" style={{ background: brand.surface1 }}>
        <div className="w-8 h-8 rounded-full flex items-center justify-center mb-2" style={{ background: `${brand.success}20` }}>
          <Icon type="check" size={16} color={brand.success} />
        </div>
        <div className="text-xs font-medium" style={{ color: brand.textPrimary }}>All Clear</div>
        <div className="text-xs mt-0.5" style={{ color: brand.textSecondary }}>No actions pending</div>
      </div>
    </div>
  );

  // NEW: Danger Action (Phase 2 - Sam's P1 need)
  const DangerActionScreen = () => (
    <div className="h-full flex flex-col p-2.5" style={{ fontFamily: 'system-ui' }}>
      <div className="flex justify-end mb-1.5">
        <button className="p-1 opacity-60"><Icon type="settings" size={14} color={brand.textSecondary} /></button>
      </div>

      <div className="flex items-center gap-1.5 mb-2">
        <StatusDot state="pending" size={6} />
        <span className="text-xs" style={{ color: brand.orange }}>Awaiting</span>
      </div>

      {/* DANGER CARD - Red border for destructive operations */}
      <div
        className="flex-1 rounded-xl p-2.5 flex flex-col"
        style={{
          background: brand.dangerBackground,
          border: `2px solid ${brand.danger}`,
        }}
      >
        <DangerIndicator />

        <div className="flex items-center gap-1 mt-2 mb-1">
          <Icon type="terminal" size={10} color={brand.danger} />
          <span className="text-xs" style={{ color: brand.textPrimary, fontFamily: 'monospace', fontSize: 9 }}>bash</span>
        </div>
        <div className="text-xs flex-1 leading-relaxed" style={{ color: brand.textPrimary, fontFamily: 'monospace', fontSize: 9 }}>
          DELETE FROM users WHERE inactive = true
        </div>

        {/* Button order swapped for danger - Reject is prominent */}
        <div className="flex gap-2 mt-2">
          <button className="flex-1 py-1.5 rounded-lg text-xs font-medium" style={{ background: brand.danger, color: brand.textPrimary }}>
            Reject
          </button>
          <button className="flex-1 py-1.5 rounded-lg text-xs font-medium" style={{ background: brand.surface2, color: brand.textSecondary }}>
            Approve
          </button>
        </div>
      </div>

      <div className="mt-2 text-center">
        <span className="text-xs" style={{ color: brand.danger }}>Review carefully</span>
      </div>
    </div>
  );

  // NEW: Expanded Detail (Phase 4 - Sam's P2 need)
  const ExpandedDetailScreen = () => (
    <div className="h-full flex flex-col p-2.5 overflow-auto" style={{ fontFamily: 'system-ui' }}>
      <div className="flex items-center mb-2">
        <button className="p-1"><Icon type="arrowLeft" size={14} color={brand.textSecondary} /></button>
        <span className="text-xs ml-1" style={{ color: brand.textSecondary }}>Back</span>
      </div>

      <div className="text-sm font-medium mb-2" style={{ color: brand.textPrimary }}>Action Details</div>

      <div className="rounded-xl p-2.5 mb-2" style={{ background: brand.surface1 }}>
        <div className="flex items-center gap-1.5 mb-2">
          <Icon type="edit" size={12} color={brand.orange} />
          <span className="text-xs font-medium" style={{ color: brand.orange }}>Edit File</span>
        </div>

        <div className="text-xs mb-1" style={{ color: brand.textTertiary, textTransform: 'uppercase', fontSize: 9 }}>Full Path</div>
        <div className="text-xs mb-2 break-all" style={{ color: brand.textPrimary, fontFamily: 'monospace', fontSize: 9 }}>
          /Users/sam/projects/app/src/components/App.tsx
        </div>

        <div className="text-xs mb-1" style={{ color: brand.textTertiary, textTransform: 'uppercase', fontSize: 9 }}>Description</div>
        <div className="text-xs mb-2" style={{ color: brand.textSecondary, fontSize: 10 }}>
          Add dark mode toggle with system preference detection
        </div>

        <div className="text-xs mb-1" style={{ color: brand.textTertiary, textTransform: 'uppercase', fontSize: 9 }}>Received</div>
        <div className="text-xs" style={{ color: brand.textSecondary }}>2 min ago</div>
      </div>

      <div className="flex gap-2 mt-auto">
        <button className="flex-1 py-1.5 rounded-lg text-xs font-medium" style={{ background: brand.surface2, color: brand.textSecondary }}>Reject</button>
        <button className="flex-1 py-1.5 rounded-lg text-xs font-medium" style={{ background: brand.success, color: brand.background }}>Approve</button>
      </div>
    </div>
  );

  // NEW: Session History (Phase 5 - Sam's P3 need)
  const HistoryScreen = () => {
    const history = [
      { time: '2m ago', action: 'Approved', file: 'App.tsx', type: 'edit', auto: false },
      { time: '5m ago', action: 'Approved', file: 'utils.ts', type: 'edit', auto: true },
      { time: '8m ago', action: 'Approved', file: 'test.ts', type: 'create', auto: true },
      { time: '12m ago', action: 'Rejected', file: 'config.ts', type: 'delete', auto: false },
      { time: '15m ago', action: 'Approved', file: 'index.ts', type: 'edit', auto: true },
    ];

    return (
      <div className="h-full flex flex-col p-2.5" style={{ fontFamily: 'system-ui' }}>
        <div className="flex items-center mb-2">
          <button className="p-1"><Icon type="arrowLeft" size={14} color={brand.textSecondary} /></button>
          <span className="text-xs font-medium ml-1" style={{ color: brand.textPrimary }}>Session History</span>
        </div>

        <div className="flex-1 space-y-1 overflow-auto">
          {history.map((item, i) => (
            <div
              key={i}
              className="rounded-lg p-2 flex items-center gap-2"
              style={{ background: brand.surface1 }}
            >
              <div
                className="w-1.5 h-1.5 rounded-full"
                style={{ background: item.action === 'Approved' ? brand.success : brand.danger }}
              />
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1">
                  <span className="text-xs truncate" style={{ color: brand.textPrimary, fontFamily: 'monospace', fontSize: 9 }}>{item.file}</span>
                  {item.auto && <AutoBadge />}
                </div>
                <div className="text-xs" style={{ color: item.action === 'Approved' ? brand.success : brand.danger, fontSize: 9 }}>
                  {item.action}
                </div>
              </div>
              <span className="text-xs" style={{ color: brand.textTertiary, fontSize: 9 }}>{item.time}</span>
            </div>
          ))}
        </div>
      </div>
    );
  };

  // NEW: Selective Queue (Phase 6 - Sam's P3 need)
  const SelectiveQueueScreen = () => {
    const actions = [
      { id: 0, icon: 'edit', name: 'App.tsx', type: 'Edit', safe: true },
      { id: 1, icon: 'filePlus', name: 'test.ts', type: 'Create', safe: true },
      { id: 2, icon: 'edit', name: 'index.ts', type: 'Edit', safe: true },
      { id: 3, icon: 'trash', name: 'old-utils.ts', type: 'Delete', safe: false },
    ];

    const toggleAction = (id) => {
      const newSet = new Set(selectedActions);
      if (newSet.has(id)) {
        newSet.delete(id);
      } else {
        newSet.add(id);
      }
      setSelectedActions(newSet);
    };

    return (
      <div className="h-full flex flex-col p-2.5" style={{ fontFamily: 'system-ui' }}>
        <div className="flex justify-between items-center mb-2">
          <span className="text-xs font-medium" style={{ color: brand.textPrimary }}>4 Pending</span>
          <span className="text-xs" style={{ color: brand.info }}>{selectedActions.size} selected</span>
        </div>

        <div className="flex-1 space-y-1.5 overflow-auto">
          {actions.map(action => {
            const isSelected = selectedActions.has(action.id);
            const isDanger = !action.safe;
            return (
              <button
                key={action.id}
                className="w-full rounded-lg p-2 flex items-center gap-2 text-left"
                style={{
                  background: isDanger ? brand.dangerBackground : brand.surface1,
                  border: isDanger ? `1px solid ${brand.danger}40` : '1px solid transparent',
                }}
                onClick={() => toggleAction(action.id)}
              >
                <div className="w-4 h-4 flex items-center justify-center">
                  {isSelected ? (
                    <Icon type="checkSquare" size={14} color={brand.orange} />
                  ) : (
                    <Icon type="square" size={14} color={brand.textSecondary} />
                  )}
                </div>
                <Icon type={action.icon} size={12} color={isDanger ? brand.danger : brand.orange} />
                <div className="flex-1 min-w-0">
                  <div className="text-xs truncate" style={{ color: brand.textPrimary, fontFamily: 'monospace', fontSize: 10 }}>{action.name}</div>
                  <div className="text-xs" style={{ color: isDanger ? brand.danger : brand.textTertiary, fontSize: 9 }}>{action.type}</div>
                </div>
                {isDanger && <Icon type="alert" size={10} color={brand.danger} />}
              </button>
            );
          })}
        </div>

        <div className="flex gap-2 mt-2">
          <button className="flex-1 py-1.5 rounded-lg text-xs font-medium" style={{ background: brand.danger, color: brand.textPrimary }}>
            Reject ({4 - selectedActions.size})
          </button>
          <button className="flex-1 py-1.5 rounded-lg text-xs font-medium" style={{ background: brand.success, color: brand.background }}>
            Approve ({selectedActions.size})
          </button>
        </div>
      </div>
    );
  };

  // Multiple Actions with Review Button
  const MultipleActionsScreen = () => (
    <div className="h-full flex flex-col p-2.5" style={{ fontFamily: 'system-ui' }}>
      <div className="flex justify-end mb-1.5">
        <button className="p-1 opacity-60"><Icon type="settings" size={14} color={brand.textSecondary} /></button>
      </div>

      <div className="flex items-center gap-1.5 mb-2">
        <StatusDot state="pending" size={6} />
        <span className="text-xs" style={{ color: brand.orange }}>4 Pending</span>
      </div>

      {/* First action card */}
      <div className="flex-1 rounded-xl p-2.5 flex flex-col" style={{ background: brand.surface1 }}>
        <div className="flex items-center gap-1.5 mb-1">
          <Icon type="edit" size={12} color={brand.orange} />
          <span className="text-xs font-medium" style={{ color: brand.orange }}>Edit</span>
          <div className="ml-auto w-5 h-5 rounded-full flex items-center justify-center text-xs font-bold" style={{ background: brand.orange, color: brand.background }}>
            4
          </div>
        </div>
        <div className="text-xs mb-0.5" style={{ color: brand.textPrimary, fontFamily: 'monospace' }}>src/App.tsx</div>
        <div className="text-xs flex-1" style={{ color: brand.textSecondary, fontSize: 10 }}>
          Add dark mode toggle
        </div>

        <div className="flex gap-2 mt-2">
          <button className="flex-1 py-1.5 rounded-lg text-xs font-medium flex items-center justify-center gap-1" style={{ background: brand.surface2, color: brand.textSecondary }}>
            <Icon type="x" size={10} color={brand.textSecondary} />
          </button>
          <button className="flex-1 py-1.5 rounded-lg text-xs font-medium flex items-center justify-center gap-1" style={{ background: brand.success, color: brand.background }}>
            <Icon type="check" size={10} color={brand.background} />
          </button>
        </div>
      </div>

      {/* Review + Approve All buttons */}
      <div className="flex gap-2 mt-2">
        <button className="flex-1 py-1.5 rounded-lg text-xs font-medium" style={{ background: brand.info, color: brand.textPrimary }}>
          Review
        </button>
        <button className="flex-1 py-1.5 rounded-lg text-xs font-medium" style={{ background: brand.success, color: brand.background }}>
          All ✓
        </button>
      </div>
    </div>
  );

  const watchScreens = {
    'main-pending': { component: <MainPendingScreen />, label: 'Single Action', phase: 'Original' },
    'progress-eta': { component: <ProgressETAScreen />, label: 'Progress + ETA', phase: 'Phase 3' },
    'danger': { component: <DangerActionScreen />, label: 'Danger Pattern', phase: 'Phase 2' },
    'expanded': { component: <ExpandedDetailScreen />, label: 'Expanded Detail', phase: 'Phase 4' },
    'history': { component: <HistoryScreen />, label: 'Session History', phase: 'Phase 5' },
    'selective': { component: <SelectiveQueueScreen />, label: 'Selective Queue', phase: 'Phase 6' },
    'multiple': { component: <MultipleActionsScreen />, label: 'Multiple Actions', phase: 'Phase 6' },
  };

  // ==========================================================================
  // MAIN RENDER
  // ==========================================================================
  return (
    <div className="min-h-screen" style={{ background: brand.brandLight, fontFamily: 'system-ui' }}>
      {/* Navigation */}
      <nav className="sticky top-0 z-50 border-b" style={{ background: brand.brandLight, borderColor: '#e5e5e5' }}>
        <div className="max-w-6xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ background: brand.orange }}>
                <Icon type="terminal" size={20} color="#fff" />
              </div>
              <div>
                <h1 className="text-lg font-semibold" style={{ color: brand.brandDark }}>
                  Claude Watch
                </h1>
                <p className="text-xs" style={{ color: brand.textSecondary }}>
                  Design System — Post-Overhaul
                </p>
              </div>
            </div>

            <div className="flex gap-1">
              {['overview', 'screens', 'tokens'].map(view => (
                <button
                  key={view}
                  onClick={() => setActiveView(view)}
                  className="px-3 py-2 rounded-lg text-sm font-medium transition-colors capitalize"
                  style={{
                    background: activeView === view ? brand.brandDark : 'transparent',
                    color: activeView === view ? '#fff' : brand.textSecondary,
                  }}
                >
                  {view}
                </button>
              ))}
            </div>
          </div>
        </div>
      </nav>

      {/* OVERVIEW */}
      {activeView === 'overview' && (
        <div className="max-w-6xl mx-auto px-6 py-10">
          <div className="text-center mb-10">
            <h2 className="text-3xl font-bold mb-2" style={{ color: brand.brandDark }}>
              Design System Overhaul Complete
            </h2>
            <p style={{ color: brand.textSecondary }}>
              All 6 phases implemented. See the new features below.
            </p>
          </div>

          {/* Phase summary cards */}
          <div className="grid md:grid-cols-3 gap-4 mb-10">
            {[
              { phase: '1', title: 'Token Alignment', desc: 'Added dangerBackground, brandDark/Light, ModeColors', color: brand.info },
              { phase: '2', title: 'Danger Pattern', desc: 'Red borders, DangerIndicator for destructive ops', color: brand.danger },
              { phase: '3', title: 'Progress + ETA', desc: 'Time remaining estimates for Jordan', color: brand.success },
              { phase: '4', title: 'Expanded Detail', desc: 'Long-press for full action info', color: brand.orange },
              { phase: '5', title: 'Session History', desc: 'Audit trail with auto badge', color: brand.modePlan },
              { phase: '6', title: 'Selective Queue', desc: 'Checkbox selection for batch control', color: brand.info },
            ].map((item, i) => (
              <div
                key={i}
                className="p-5 rounded-xl"
                style={{ background: '#fff', border: '1px solid #e5e5e5' }}
              >
                <div className="flex items-center gap-2 mb-2">
                  <div
                    className="w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold"
                    style={{ background: item.color, color: '#fff' }}
                  >
                    {item.phase}
                  </div>
                  <div className="text-base font-semibold" style={{ color: brand.brandDark }}>
                    {item.title}
                  </div>
                </div>
                <p className="text-sm" style={{ color: brand.textSecondary }}>
                  {item.desc}
                </p>
              </div>
            ))}
          </div>

          {/* Preview grid */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            {Object.entries(watchScreens).slice(0, 4).map(([key, { component, label, phase }]) => (
              <div key={key} className="flex flex-col items-center">
                <WatchFrame scale={0.75}>
                  {component}
                </WatchFrame>
                <div className="mt-2 text-center">
                  <div className="text-sm font-medium" style={{ color: brand.brandDark }}>{label}</div>
                  <div className="text-xs" style={{ color: phase.includes('Phase') ? brand.success : brand.textSecondary }}>{phase}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* SCREENS */}
      {activeView === 'screens' && (
        <div className="max-w-6xl mx-auto px-6 py-10">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold mb-2" style={{ color: brand.brandDark }}>
              All Watch Screens
            </h2>
            <p style={{ color: brand.textSecondary }}>
              Click to preview. Each tagged with implementation phase.
            </p>
          </div>

          {/* Screen selector */}
          <div className="flex flex-wrap justify-center gap-1.5 mb-8">
            {Object.entries(watchScreens).map(([key, { label, phase }]) => (
              <button
                key={key}
                onClick={() => setWatchScreen(key)}
                className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                style={{
                  background: watchScreen === key ? brand.orange : '#e5e5e5',
                  color: watchScreen === key ? '#fff' : brand.textSecondary,
                }}
              >
                {label}
                <span className="ml-1 opacity-60">({phase})</span>
              </button>
            ))}
          </div>

          {/* Large preview */}
          <div className="rounded-2xl p-8" style={{ background: '#e5e5e5' }}>
            <div className="flex flex-col lg:flex-row items-center justify-center gap-8">
              <WatchFrame scale={1.3}>
                {watchScreens[watchScreen].component}
              </WatchFrame>

              <div className="max-w-md">
                <div className="flex items-center gap-2 mb-2">
                  <h3 className="text-xl font-bold" style={{ color: brand.brandDark }}>
                    {watchScreens[watchScreen].label}
                  </h3>
                  <span
                    className="px-2 py-0.5 rounded text-xs font-medium"
                    style={{ background: brand.success + '20', color: brand.success }}
                  >
                    {watchScreens[watchScreen].phase}
                  </span>
                </div>
                <p style={{ color: brand.textSecondary }}>
                  {watchScreen === 'main-pending' && 'Core approval flow. Single tap to approve or reject. Target: 3-5 seconds.'}
                  {watchScreen === 'progress-eta' && 'Progress monitoring for Jordan. Shows percentage, elapsed time, and estimated time remaining with clock icon.'}
                  {watchScreen === 'danger' && 'Risk indicator for Sam. Red border, danger background, and DangerIndicator for destructive operations. Button order swapped.'}
                  {watchScreen === 'expanded' && 'Long-press detail view for Sam. Full file path, description, timestamp. Access via long-press on action card.'}
                  {watchScreen === 'history' && 'Session audit for Sam. Shows what Claude did, including auto-approved actions marked with "auto" badge.'}
                  {watchScreen === 'selective' && 'Selective queue for Sam. Checkbox selection allows approving safe actions while rejecting dangerous ones. Pre-selects safe by default.'}
                  {watchScreen === 'multiple' && 'Multiple actions view. Shows "Review" button to open SelectiveQueueView and "All ✓" for quick approve all.'}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TOKENS */}
      {activeView === 'tokens' && (
        <div className="max-w-5xl mx-auto px-6 py-10">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold mb-2" style={{ color: brand.brandDark }}>
              Design Tokens
            </h2>
            <p style={{ color: brand.textSecondary }}>
              Updated tokens from Phase 1 highlighted in green.
            </p>
          </div>

          {/* Color grid */}
          <div className="grid md:grid-cols-2 gap-4 mb-8">
            {[
              { name: 'Orange', hex: '#FF9500', usage: 'Primary accent', isNew: false },
              { name: 'Success', hex: '#34C759', usage: 'Approved state', isNew: false },
              { name: 'Danger', hex: '#FF3B30', usage: 'Rejected/error state', isNew: false },
              { name: 'Info', hex: '#007AFF', usage: 'Information, Review button', isNew: false },
              { name: 'Danger Background', hex: 'rgba(255,59,48,0.15)', usage: 'Danger card background', isNew: true },
              { name: 'Brand Dark', hex: '#141413', usage: 'Anthropic brand reference', isNew: true },
              { name: 'Brand Light', hex: '#faf9f5', usage: 'Anthropic brand reference', isNew: true },
              { name: 'Mode Plan', hex: '#9b8ac4', usage: 'Plan mode indicator', isNew: true },
            ].map((color, i) => (
              <div key={i} className="flex items-center gap-3 p-3 rounded-lg" style={{ background: '#fff', border: color.isNew ? `2px solid ${brand.success}` : '1px solid #e5e5e5' }}>
                <div className="w-10 h-10 rounded-lg" style={{ background: color.hex, border: '1px solid #e5e5e5' }} />
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-semibold" style={{ color: brand.brandDark }}>{color.name}</span>
                    {color.isNew && (
                      <span className="text-xs px-1.5 py-0.5 rounded" style={{ background: brand.success + '20', color: brand.success }}>NEW</span>
                    )}
                  </div>
                  <div className="text-xs font-mono" style={{ color: brand.textSecondary }}>{color.hex}</div>
                  <div className="text-xs" style={{ color: brand.textSecondary }}>{color.usage}</div>
                </div>
              </div>
            ))}
          </div>

          {/* New components */}
          <div className="rounded-xl p-5" style={{ background: brand.brandDark }}>
            <h3 className="text-sm font-semibold mb-4" style={{ color: '#fff' }}>
              New Components (Phases 2-6)
            </h3>
            <div className="grid md:grid-cols-2 gap-4">
              <div className="p-4 rounded-lg" style={{ background: brand.surface1 }}>
                <div className="text-xs mb-2" style={{ color: brand.textSecondary }}>DangerIndicator</div>
                <DangerIndicator />
              </div>
              <div className="p-4 rounded-lg" style={{ background: brand.surface1 }}>
                <div className="text-xs mb-2" style={{ color: brand.textSecondary }}>DangerBadge</div>
                <DangerBadge />
              </div>
              <div className="p-4 rounded-lg" style={{ background: brand.surface1 }}>
                <div className="text-xs mb-2" style={{ color: brand.textSecondary }}>ETADisplay</div>
                <ETADisplay eta="~8m left" />
              </div>
              <div className="p-4 rounded-lg" style={{ background: brand.surface1 }}>
                <div className="text-xs mb-2" style={{ color: brand.textSecondary }}>AutoBadge</div>
                <AutoBadge />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Footer */}
      <footer className="border-t py-6" style={{ borderColor: '#e5e5e5' }}>
        <div className="max-w-6xl mx-auto px-6 text-center">
          <p className="text-sm" style={{ color: brand.textSecondary }}>
            Claude Watch Design System — All 6 Phases Complete
          </p>
        </div>
      </footer>
    </div>
  );
};

export default ClaudeWatchUpdated;
