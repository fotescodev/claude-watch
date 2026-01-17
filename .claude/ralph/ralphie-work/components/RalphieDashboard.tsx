
import React, { useState, useEffect } from 'react';

// ASCII Sparkline for trends
const Sparkline: React.FC<{ data: number[]; color?: string; label: string }> = ({ data, color = "text-primary", label }) => {
  const chars = [' ', '▂', '▃', '▄', '▅', '▆', '▇', '█'];
  const max = Math.max(...data, 1);
  return (
    <div className="flex flex-col gap-1">
      <div className="flex justify-between items-center text-[8px] uppercase tracking-widest text-slate-600 font-bold">
        <span>{label}</span>
        <span className={color}>{data[data.length - 1]}%</span>
      </div>
      <div className={`flex items-end h-4 font-mono ${color} gap-px`}>
        {data.map((v, i) => (
          <span key={i} title={v.toString()}>
            {chars[Math.floor((v / max) * (chars.length - 1))]}
          </span>
        ))}
      </div>
    </div>
  );
};

const TUIBox: React.FC<{ title?: string; children: React.ReactNode; className?: string; borderStyle?: 'single' | 'double' }> = ({ 
  title, 
  children, 
  className = "",
  borderStyle = 'single'
}) => {
  const borderClass = borderStyle === 'double' ? 'border-2' : 'border';
  return (
    <div className={`${borderClass} border-white/10 bg-black relative p-4 transition-all duration-500 hover:border-primary/40 ${className}`}>
      {title && (
        <div className="absolute -top-3 left-3 px-2 bg-black text-[9px] font-black font-mono text-primary uppercase tracking-[0.3em]">
          {title}
        </div>
      )}
      {children}
    </div>
  );
};

const StrategyVisualizer: React.FC<{ mode: string }> = ({ mode }) => {
  const renderVisual = () => {
    switch(mode) {
      case 'SEQUENTIAL':
        return (
          <div className="flex items-center gap-2 text-[10px] text-primary animate-in fade-in duration-500">
            <span>[T1]</span>
            <span className="animate-pulse">──▶</span>
            <span className="opacity-40">[T2]</span>
            <span className="opacity-20">──▶</span>
            <span className="opacity-10">[T3]</span>
          </div>
        );
      case 'GROUPED':
        return (
          <div className="flex items-center gap-2 text-[10px] text-cyan-400 animate-in fade-in duration-500">
            <span className="border border-cyan-500/30 px-1">{`{ T1, T2, T3 }`}</span>
            <span className="animate-pulse">══▶</span>
            <span>[BUNDLE_RESULT]</span>
          </div>
        );
      case 'PARALLEL':
        return (
          <div className="flex flex-col gap-1 text-[9px] text-white animate-in fade-in duration-500">
            <div className="flex items-center gap-2"><span>Shard_A:</span> <span className="text-primary animate-pulse">■■■■□</span></div>
            <div className="flex items-center gap-2"><span>Shard_B:</span> <span className="text-cyan-400 animate-pulse">■■□□□</span></div>
            <div className="flex items-center gap-2"><span>Shard_C:</span> <span className="text-green-500 animate-pulse">■■■■■</span></div>
          </div>
        );
      case 'SHARDING':
        return (
          <div className="flex items-center gap-2 text-[10px] text-yellow-500 animate-in fade-in duration-500">
            <span className="bg-yellow-500/20 px-1 font-bold">MASTER_TASK</span>
            <span className="text-white">⇒</span>
            <div className="flex flex-col gap-0.5 scale-75">
               <span className="bg-white/10 px-1 text-[8px]">S1</span>
               <span className="bg-white/10 px-1 text-[8px]">S2</span>
               <span className="bg-white/10 px-1 text-[8px]">S3</span>
            </div>
          </div>
        );
      default: return null;
    }
  };

  return (
    <div className="h-16 flex items-center justify-center border border-white/5 bg-white/[0.02] rounded-sm">
      {renderVisual()}
    </div>
  );
};

const CoffeeCupMascot: React.FC<{ state: 'IDLE' | 'THINKING' | 'LEARNING' }> = ({ state }) => {
  const [frame, setFrame] = useState(0);

  useEffect(() => {
    const speed = state === 'THINKING' ? 150 : state === 'LEARNING' ? 80 : 400;
    const timer = setInterval(() => setFrame((f) => (f + 1) % 4), speed);
    return () => clearInterval(timer);
  }, [state]);

  const steam = [
    "   (  )   \n    )(    ", 
    "    )(    \n   (  )   ",
    "   (  )   \n    )(    ",
    "    )(    \n   (  )   "
  ][frame];

  const color = state === 'LEARNING' ? 'text-cyan-400' : state === 'THINKING' ? 'text-primary' : 'text-slate-700';

  return (
    <div className="relative font-mono text-[10px] leading-[1.15] tracking-tighter whitespace-pre select-none mr-10 hidden sm:block">
      <div className={`absolute bottom-full left-0 w-full text-center h-[22px] overflow-hidden mb-1 transition-all duration-500 ${color} ${state !== 'IDLE' ? 'scale-125 opacity-100' : 'opacity-30'}`}>
        {steam}
      </div>
      <div className={`transition-all duration-700 ${state === 'LEARNING' ? 'text-cyan-500' : state === 'THINKING' ? 'text-white' : 'text-primary'}`}>
{`   ╔══════╗
   ║      ║]
    ╚════╝`}
      </div>
    </div>
  );
};

const RalphieDashboard: React.FC = () => {
  const [sysState, setSysState] = useState<'IDLE' | 'THINKING' | 'LEARNING'>('THINKING');
  const [stratMode, setStratMode] = useState<'SEQUENTIAL' | 'GROUPED' | 'PARALLEL' | 'SHARDING'>('PARALLEL');
  
  const threads = [
    { id: 'SHARD-01', work: 'UI_REFACTOR', progress: 84, status: 'BUSY' },
    { id: 'SHARD-02', work: 'AUTH_LOGIC', progress: 42, status: 'BUSY' },
    { id: 'SHARD-03', work: 'TEST_GEN', progress: 100, status: 'IDLE' },
    { id: 'SHARD-04', work: 'API_STUBBING', progress: 12, status: 'STALLED' },
  ];

  useEffect(() => {
    const cycle = setInterval(() => {
      setSysState(prev => {
        if (prev === 'IDLE') return 'THINKING';
        if (prev === 'THINKING') return 'LEARNING';
        return 'IDLE';
      });
      setStratMode(prev => {
        const modes: any[] = ['SEQUENTIAL', 'GROUPED', 'PARALLEL', 'SHARDING'];
        const nextIdx = (modes.indexOf(prev) + 1) % modes.length;
        return modes[nextIdx];
      });
    }, 6000);
    return () => clearInterval(cycle);
  }, []);

  return (
    <div className="w-full max-w-7xl mx-auto bg-black p-4 font-mono text-slate-300 selection:bg-primary selection:text-black animate-in fade-in duration-1000">
      <div className="border border-white/20 p-1 flex flex-col min-h-[850px] shadow-2xl relative">
        
        {/* Header HUD */}
        <div className="flex justify-between items-center border-b border-white/20 pb-8 px-8 pt-10 mb-6 relative overflow-hidden">
          {sysState === 'LEARNING' && <div className="absolute inset-0 bg-cyan-500/5 animate-pulse pointer-events-none"></div>}
          
          <div className="flex items-center">
            <CoffeeCupMascot state={sysState} />
            <div className="flex flex-col">
              <h1 className="text-3xl font-black text-white tracking-widest uppercase leading-none mb-2 flex items-center">
                <span className={sysState === 'LEARNING' ? 'text-cyan-400' : 'text-primary'}>RALPHIE</span> 
                <span className="text-[10px] ml-4 border border-white/10 px-2 py-1 text-slate-500 font-normal tracking-normal uppercase">CORE_v1.2_MULTI_SHARD</span>
              </h1>
              <div className="flex items-center gap-4 text-[9px] text-slate-500 font-bold uppercase tracking-[0.2em]">
                <span className="flex items-center gap-1.5 text-primary">
                  <span className={`w-2 h-2 rounded-full ${sysState !== 'IDLE' ? 'bg-primary animate-ping' : 'bg-slate-800'}`}></span>
                  SYSTEM_MODE: <span className="text-white">{sysState}</span>
                </span>
                <span className="opacity-20">|</span>
                <span>CLUSTER_NODES: 04_ACTIVE</span>
              </div>
            </div>
          </div>
          
          <div className="flex gap-10 text-xs">
            <div className="flex flex-col items-end">
              <span className="text-slate-600 text-[9px] uppercase tracking-widest mb-1">Compute Cost</span>
              <span className="text-green-500 font-bold">$1.12 / HR</span>
            </div>
            <div className="flex flex-col items-end">
              <span className="text-slate-600 text-[9px] uppercase tracking-widest mb-1">Global Health</span>
              <span className="text-cyan-400 font-bold tracking-widest">OPTIMAL</span>
            </div>
          </div>
        </div>

        {/* Dynamic Grid Layout */}
        <div className="grid grid-cols-12 gap-5 px-6 flex-1">
          
          {/* Column 1: Strategy & Shards */}
          <div className="col-span-12 lg:col-span-4 flex flex-col gap-5">
            <TUIBox title="ORCHESTRATION_STRATEGY">
               <div className="space-y-4">
                  <div className="flex justify-between items-center text-[10px] font-bold">
                    <span className="text-slate-500">CURRENT_MODE:</span>
                    <span className="text-primary bg-primary/10 px-2 py-0.5">{stratMode}</span>
                  </div>
                  <StrategyVisualizer mode={stratMode} />
                  <p className="text-[9px] text-slate-500 italic leading-relaxed">
                    {stratMode === 'SEQUENTIAL' && "Linear execution for high-risk dependency chains."}
                    {stratMode === 'GROUPED' && "Batch processing related tasks in single context window."}
                    {stratMode === 'PARALLEL' && "Concurrent execution across multiple heterogeneous domains."}
                    {stratMode === 'SHARDING' && "Horizontal distribution of homogeneous massive workloads."}
                  </p>
               </div>
            </TUIBox>

            <TUIBox title="THREAD_LOAD" className="flex-1">
               <div className="space-y-4">
                  {threads.map((t) => (
                    <div key={t.id} className="border border-white/5 bg-white/[0.02] p-3 group hover:border-primary/40 transition-all">
                       <div className="flex justify-between text-[9px] font-bold mb-2">
                          <span className="text-primary tracking-widest">{t.id}</span>
                          <span className={t.status === 'BUSY' ? 'text-cyan-400 animate-pulse' : 'text-slate-600'}>{t.status}</span>
                       </div>
                       <div className="h-1 bg-white/5 rounded-full overflow-hidden">
                          <div 
                            className={`h-full transition-all duration-1000 ${t.status === 'STALLED' ? 'bg-red-500' : 'bg-primary'}`} 
                            style={{ width: `${t.progress}%` }}
                          ></div>
                       </div>
                    </div>
                  ))}
               </div>
            </TUIBox>
          </div>

          {/* Column 2: Cognitive Trace & Feedback */}
          <div className="col-span-12 lg:col-span-5 flex flex-col gap-5">
            <TUIBox title="METACOGNITIVE_FEEDBACK" className="bg-cyan-500/[0.03] border-cyan-500/20">
               <div className="space-y-3 text-[10px]">
                  <p className="text-cyan-400 font-bold uppercase tracking-widest border-b border-cyan-500/20 pb-1 mb-2"># Loop_Improvement_v92:</p>
                  <div className="space-y-2 font-mono italic text-slate-400">
                    <p className="not-italic text-slate-200">{"[CRITIQUE]"} Shard-04 stalled on API timeout. Orchestrator was too aggressive.</p>
                    <p>{"[HEURISTIC]"} Increasing retry backoff for Shard-04 next loop.</p>
                    <p>{"[LEARNING]"} Successful pattern found in Shard-01. Porting logic to v2 template.</p>
                    <p className="text-cyan-400 font-bold not-italic mt-2">PREDICTED_EFFICIENCY: +6.8% NEXT_LOOP</p>
                  </div>
               </div>
            </TUIBox>

            <TUIBox title="COGNITIVE_TRACE" className="flex-1 bg-white/[0.02] relative overflow-hidden">
               {sysState === 'LEARNING' && <div className="absolute top-2 right-2 px-2 py-0.5 bg-cyan-500/20 text-cyan-400 text-[8px] font-bold animate-pulse">OPTIMIZING...</div>}
               <div className="text-[11px] font-mono leading-relaxed space-y-4 h-full overflow-y-auto custom-scrollbar pr-2">
                  <div className="border-l-2 border-primary pl-4 py-1">
                    <p className="text-primary font-bold mb-1">THOUGHT: Strategy Selection</p>
                    <p className="text-slate-300">Switching to {stratMode} to optimize for current task density. Predicting 12% gain in throughput.</p>
                  </div>
                  <div className="border-l-2 border-cyan-500 pl-4 py-1">
                    <p className="text-cyan-400 font-bold mb-1">METACRITIQUE: Parallelization</p>
                    <p className="text-slate-400 italic">Self-correction: Previous shard merge was inefficient. Adding validation hook at T+4s.</p>
                  </div>
               </div>
            </TUIBox>
          </div>

          {/* Column 3: Telemetry & Evolution */}
          <div className="col-span-12 lg:col-span-3 flex flex-col gap-5">
            <TUIBox title="SYSTEM_PRESSURE">
               <div className="space-y-6">
                  <Sparkline data={[10, 15, 20, 22, 18, 45, 80, 85, 90, 88]} label="COMPUTE_INTENSITY" color="text-primary" />
                  <Sparkline data={[85, 84, 86, 88, 92, 95, 98, 99, 99, 100]} label="LEARNING_RATE" color="text-cyan-400" />
               </div>
            </TUIBox>

            <TUIBox title="EVOLUTION_PATH" className="flex-1">
               <div className="space-y-4">
                  <div className="space-y-2">
                    <p className="text-[9px] text-slate-600 uppercase font-bold border-b border-white/5 pb-1">Milestones</p>
                    {[
                      { id: 'E-01', label: 'Self-Healing Shards', s: 'DONE' },
                      { id: 'E-02', label: 'Metacognitive Critique', s: 'ACTIVE' },
                      { id: 'E-03', label: 'Recursive Optimization', s: 'READY' },
                    ].map(t => (
                      <div key={t.id} className="flex items-center gap-3 text-[10px]">
                        <span className={t.s === 'DONE' ? 'text-green-500' : t.s === 'ACTIVE' ? 'text-primary' : 'text-slate-700'}>
                          {t.s === 'DONE' ? '●' : t.s === 'ACTIVE' ? '◎' : '○'}
                        </span>
                        <span className={t.s === 'DONE' ? 'text-slate-600 line-through' : 'text-slate-300'}>{t.label}</span>
                      </div>
                    ))}
                  </div>
               </div>
               
               <div className="mt-auto pt-6 space-y-2">
                  <button className="w-full py-3 bg-primary/10 border border-primary/40 text-primary text-[10px] font-black uppercase tracking-[0.2em] hover:bg-primary hover:text-black transition-all active:scale-95 shadow-lg shadow-primary/10">
                     UPGRADE_INTELLIGENCE
                  </button>
               </div>
            </TUIBox>
          </div>
        </div>

        {/* Global Control Bar */}
        <div className="mt-5 border-t border-white/20 p-5 bg-gradient-to-r from-black via-white/[0.04] to-black">
           <div className="flex flex-wrap items-center justify-between gap-6">
              <div className="flex items-center gap-8">
                <div className="flex items-center gap-3">
                  <div className={`w-3 h-3 rounded-full ${sysState !== 'IDLE' ? 'bg-primary' : 'bg-slate-800'}`}></div>
                  <span className="text-[10px] font-black text-white uppercase tracking-widest">RALPH_ORCHESTRATOR</span>
                </div>
                <div className="hidden md:flex gap-6 border-l border-white/10 pl-6">
                   <div className="flex flex-col">
                      <span className="text-[8px] text-slate-600 uppercase">Context_Length</span>
                      <span className="text-[10px] font-bold text-white">194.5K / 200K</span>
                   </div>
                   <div className="flex flex-col">
                      <span className="text-[8px] text-slate-600 uppercase">Latency</span>
                      <span className="text-[10px] font-bold text-cyan-400">1.04s</span>
                   </div>
                </div>
              </div>

              <div className="flex items-center gap-4">
                 <div className="bg-white/5 border border-white/10 px-4 py-2.5 rounded flex items-center gap-6">
                    <span className="text-[10px] text-slate-500 uppercase">
                      <span className="bg-white/10 px-1 text-white mx-1 font-bold">MODE</span> {stratMode}
                    </span>
                 </div>
                 <button className="bg-white text-black px-6 py-2.5 text-[10px] font-black uppercase tracking-[0.2em] hover:bg-primary transition-colors">
                   STOP_ALL
                 </button>
              </div>
           </div>
        </div>

      </div>
      <div className="flex justify-between mt-4 text-[10px] text-slate-800 uppercase tracking-[0.6em] font-black">
         <span>Anthropic Design Lab // Lab-02</span>
         <span>Metacognitive Orchestrator [Ralphie-X]</span>
      </div>
    </div>
  );
};

export default RalphieDashboard;
