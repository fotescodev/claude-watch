
import React, { useState, useEffect, useRef } from 'react';
import { VariantType, FlowStep, HubCategory, PermissionMode } from './types';
import { VARIANTS, WATCH_SIZES, TOKENS, APP_VERSION } from './constants';
import VariantIcon from './components/VariantIcon';
import WatchMock from './components/WatchMock';
import RalphieDashboard from './components/RalphieDashboard';
import RalphiePRD from './components/RalphiePRD';
import { analyzeDesign } from './services/geminiService';

const App: React.FC = () => {
  // Default to RALPHIE to show the new section immediately
  const [activeCategory, setActiveCategory] = useState<HubCategory>(HubCategory.RALPHIE);
  const [currentStep, setCurrentStep] = useState<FlowStep>(FlowStep.ICON);
  const [permissionMode, setPermissionMode] = useState<PermissionMode>(PermissionMode.NORMAL);
  const [aiFeedback, setAiFeedback] = useState<string | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [currentTime, setCurrentTime] = useState(new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
  const [isExporting, setIsExporting] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const timer = setInterval(() => {
      const now = new Date();
      setCurrentTime(now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
    }, 10000);
    return () => clearInterval(timer);
  }, []);

  const handleAnalyze = async () => {
    setIsAnalyzing(true);
    setAiFeedback(null);
    const context = `Audit for ${currentStep} - Mode: ${permissionMode}. Focus on watchOS 2026 liquid glass semantics.`;
    const feedback = await analyzeDesign(currentStep, context);
    setAiFeedback(feedback);
    setIsAnalyzing(false);
  };

  const drawIconToCanvas = (ctx: CanvasRenderingContext2D, size: number, isCircle: boolean) => {
    const scale = size / 96;
    ctx.clearRect(0, 0, size, size);
    ctx.fillStyle = TOKENS.COLORS.BRAND.ORANGE;
    if (isCircle) {
      ctx.beginPath();
      ctx.arc(size/2, size/2, size/2, 0, Math.PI*2);
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.roundRect(0, 0, size, size, size * 0.225);
      ctx.fill();
    }

    ctx.fillStyle = '#BF6446';
    ctx.beginPath();
    ctx.roundRect(size * 0.9, size * 0.22, size * 0.04, size * 0.28, size * 0.02);
    ctx.fill();

    ctx.fillStyle = '#1A1A1A';
    ctx.beginPath();
    ctx.arc(size * 0.38, size * 0.38, size * 0.05, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillRect(size * 0.54, size * 0.33, size * 0.14, size * 0.14);
    
    ctx.strokeStyle = '#1A1A1A';
    ctx.lineWidth = 2.5 * scale;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.arc(size * 0.48, size * 0.55, size * 0.09, 0.15 * Math.PI, 0.85 * Math.PI);
    ctx.stroke();
  };

  const downloadAssets = async () => {
    setIsExporting(true);
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    for (const spec of WATCH_SIZES) {
      canvas.width = spec.size; canvas.height = spec.size;
      drawIconToCanvas(ctx, spec.size, spec.shape === 'circle');
      const link = document.createElement('a');
      link.download = `claude_watch_${spec.label}.png`;
      link.href = canvas.toDataURL();
      link.click();
      await new Promise(r => setTimeout(r, 150));
    }
    setIsExporting(false);
  };

  const renderFoundations = () => (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-8 w-full animate-in fade-in duration-500">
      <div className="space-y-6">
        <h3 className="text-white text-xs font-black uppercase tracking-[0.4em] mb-4">Color Palette</h3>
        <div className="grid grid-cols-2 gap-4">
          {Object.entries(TOKENS.COLORS.BRAND).map(([name, hex]) => (
            <div key={name} className="bg-white/5 p-4 rounded-3xl border border-white/10 flex items-center space-x-4">
              <div className="w-12 h-12 rounded-2xl shadow-xl" style={{ backgroundColor: hex }}></div>
              <div>
                <p className="text-[10px] text-slate-500 font-bold uppercase">{name}</p>
                <p className="text-xs text-white font-mono">{hex}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const renderWatchContent = () => {
    switch (currentStep) {
      case FlowStep.ICON:
        return (
          <div className="w-full h-full flex flex-col items-center justify-center space-y-6 bg-gradient-to-b from-[#1C1C1E] to-black p-6">
            <VariantIcon type={VariantType.MASCOT} active={true} pixelSize={112} />
            <div className="text-center space-y-2">
              <h2 className="text-[15px] font-black text-white tracking-[0.2em] uppercase">Claude</h2>
              <p className="text-[10px] text-primary font-bold tracking-[0.3em] opacity-80 animate-pulse uppercase">Active</p>
            </div>
          </div>
        );
      case FlowStep.PAIRING:
        return (
          <div className="w-full h-full bg-black flex flex-col items-center justify-center p-6 space-y-5 text-center">
             <div className="relative w-28 h-28 flex items-center justify-center group">
                <div className="absolute inset-0 rounded-full border-2 border-primary/20 animate-ping opacity-40"></div>
                <div className="absolute inset-4 rounded-full border border-primary/40 animate-pulse opacity-60"></div>
                
                <div className="relative w-22 h-22 bg-white rounded-3xl overflow-hidden p-3.5 grid grid-cols-4 gap-1.5 shadow-2xl transition-transform group-hover:scale-105">
                  {[...Array(16)].map((_, i) => (
                    <div 
                      key={i} 
                      className={`rounded-[2px] transition-colors duration-500 ${i % 3 === 0 ? 'bg-primary' : 'bg-black/10'}`} 
                      style={{ 
                        animation: `pulse 2s infinite ease-in-out`,
                        animationDelay: `${i * 120}ms`
                      }}
                    ></div>
                  ))}
                  <div className="absolute top-0 left-0 w-full h-1 bg-primary/90 shadow-[0_0_15px_#D97757] animate-scan z-20"></div>
                </div>
             </div>
             <div className="space-y-1.5">
                <p className="text-white text-[14px] font-black tracking-tight">Pair with iOS</p>
                <p className="text-slate-500 text-[10px] leading-tight px-4 font-medium">Scan code in Claude Terminal<br/>on your companion device.</p>
             </div>
             <button className="bg-primary text-black px-8 py-2.5 rounded-full text-[10px] font-black uppercase tracking-[0.2em] mt-2 active:scale-95 transition-transform shadow-lg shadow-primary/20">
               Open Scanner
             </button>
          </div>
        );
      case FlowStep.COMPLICATION:
        return (
          <div className="w-full h-full bg-black relative flex flex-col justify-between p-6">
            <div className="flex justify-between items-center pt-2">
              <span className="text-[16px] font-black text-white tracking-tighter">{currentTime}</span>
              <div className="w-2 h-2 rounded-full bg-green-500 shadow-[0_0_12px_#22c55e]"></div>
            </div>
            <div className="w-full bg-white/[0.08] backdrop-blur-3xl border border-white/10 rounded-[2.2rem] p-5">
              <div className="flex items-center space-x-2 mb-3">
                <div className="w-5 h-5 bg-primary rounded-full flex items-center justify-center">
                  <div className="w-2 h-2 bg-black rounded-[1px]"></div>
                </div>
                <span className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Compiler</span>
              </div>
              <p className="text-[16px] font-black text-white mb-2">Build <span className="text-primary italic">Success</span></p>
              <div className="h-1.5 bg-white/10 rounded-full overflow-hidden">
                <div className="w-[88%] h-full bg-primary"></div>
              </div>
            </div>
            <div className="flex justify-center pb-4">
              <div className="w-14 h-14 flex items-center justify-center group cursor-pointer active:scale-90 transition-transform">
                 <VariantIcon 
                    type={VariantType.MASCOT} 
                    active={true} 
                    pixelSize={52} 
                    shape="squircle"
                 />
              </div>
            </div>
          </div>
        );
      case FlowStep.INTERFACE:
        const [timePart, ampmPart] = currentTime.split(' ');
        return (
          <div className="w-full h-full bg-black flex flex-col p-2">
            <div className="flex justify-between items-start mb-2 px-3 pt-2">
              <div className="flex flex-col">
                <span className="text-[9px] font-black text-slate-500 tracking-[0.1em] leading-tight uppercase">{permissionMode}</span>
                <span className="text-[9px] font-black text-slate-500 tracking-[0.1em] leading-tight uppercase">MODE</span>
              </div>
              <div className="flex flex-col items-end">
                <span className="text-[14px] font-black text-primary leading-tight tracking-tighter">{timePart}</span>
                <span className="text-[9px] font-black text-primary/60 tracking-[0.1em] leading-tight uppercase">{ampmPart}</span>
              </div>
            </div>

            <div className="flex-1 bg-white/[0.04] rounded-[2.2rem] p-5 border border-white/5 flex flex-col mb-2 overflow-hidden shadow-inner backdrop-blur-md">
               <div className="font-mono text-[8.5px] text-slate-200 space-y-2.5">
                  <p className="text-[#D97757] font-bold opacity-90">~/auth_service.ts</p>
                  <div className="flex items-start space-x-2 border-l-2 border-[#D97757] pl-3 ml-0.5">
                    <span className="text-[#D97757] font-black">✓</span>
                    <p className="text-white font-medium">Token validation added</p>
                  </div>
                  <div className="flex items-start space-x-2 border-l-2 border-white/10 pl-3 ml-0.5">
                    <p className="text-slate-500 animate-pulse">Running checks...</p>
                  </div>
               </div>
            </div>

            <div className="flex space-x-2 px-1 pb-2">
               <button 
                  onClick={() => setPermissionMode(PermissionMode.NORMAL)} 
                  className={`flex-1 py-3.5 rounded-full text-[9px] font-black uppercase transition-all shadow-lg active:scale-95 ${permissionMode === PermissionMode.NORMAL ? 'bg-[#D97757] text-black shadow-[#D97757]/20' : 'bg-[#1C1C1E] text-slate-400 border border-white/5'}`}
               >
                 Normal
               </button>
               <button 
                  onClick={() => setPermissionMode(PermissionMode.AUTO_ACCEPT)} 
                  className={`flex-1 py-3.5 rounded-full text-[9px] font-black uppercase transition-all shadow-lg active:scale-95 ${permissionMode === PermissionMode.AUTO_ACCEPT ? 'bg-[#D97757] text-black shadow-[#D97757]/20' : 'bg-[#1C1C1E] text-slate-400 border border-white/5'}`}
               >
                 Auto
               </button>
            </div>
          </div>
        );
      case FlowStep.NOTIFICATION:
        return (
          <div className="w-full h-full bg-[#0A0A0B] flex flex-col p-4 animate-in fade-in slide-in-from-bottom-4 duration-500">
            {/* Safe zone header */}
            <div className="flex items-center space-x-2 mb-4 px-2">
              <VariantIcon type={VariantType.MASCOT} active={true} pixelSize={24} shape="squircle" />
              <span className="text-[10px] font-black text-[#D97757] uppercase tracking-[0.2em]">Claude</span>
            </div>
            
            {/* Notification Body */}
            <div className="flex-1 bg-white/[0.05] rounded-[1.8rem] border border-white/10 p-4 space-y-2">
              <h3 className="text-[15px] font-black text-white tracking-tight">Access Request</h3>
              <p className="text-[12px] text-slate-400 leading-tight">Terminal 12-4A is requesting read access to ~/Documents/secrets.</p>
            </div>

            {/* Actions */}
            <div className="mt-3 flex flex-col space-y-2 px-1 pb-1">
              <button className="w-full py-3 bg-[#D97757] text-black rounded-full text-[10px] font-black uppercase tracking-widest shadow-lg shadow-primary/20 active:scale-95 transition-transform">
                Allow Once
              </button>
              <button className="w-full py-3 bg-white/[0.06] text-white rounded-full text-[10px] font-black uppercase tracking-widest border border-white/5 active:scale-95 transition-transform">
                Deny
              </button>
            </div>
          </div>
        );
      case FlowStep.VOICE:
        return (
          <div className="w-full h-full bg-black flex flex-col items-center justify-between p-6">
            <div className="w-full flex justify-between items-center text-[13px] font-bold text-slate-500 px-2">
              <span>Claude</span>
              <span className="text-primary">{currentTime}</span>
            </div>

            {/* Living Waveform / Voice Orb */}
            <div className="relative w-28 h-28 flex items-center justify-center">
              {[...Array(3)].map((_, i) => (
                <div 
                  key={i} 
                  className="absolute inset-0 border-2 border-primary/30 rounded-full animate-pulse"
                  style={{ 
                    animationDelay: `${i * 300}ms`,
                    transform: `scale(${1 + i * 0.2})`,
                    opacity: 1 - i * 0.3
                  }}
                ></div>
              ))}
              <div className="relative w-16 h-16 bg-primary rounded-full shadow-[0_0_30px_rgba(217,119,87,0.5)] flex items-center justify-center overflow-hidden">
                <div className="flex items-center space-x-1">
                  {[...Array(5)].map((_, i) => (
                    <div 
                      key={i} 
                      className="w-1 bg-black rounded-full"
                      style={{ 
                        height: '20px',
                        animation: `pulse ${0.5 + Math.random()}s infinite ease-in-out`,
                        animationDelay: `${i * 100}ms`
                      }}
                    ></div>
                  ))}
                </div>
              </div>
            </div>

            {/* Transcription safe zone */}
            <div className="w-full bg-white/[0.04] p-4 rounded-[1.5rem] border border-white/5 mb-2">
              <p className="text-[13px] font-serif italic text-white/80 text-center leading-snug">
                "Show me the last deployment status of the auth service..."
              </p>
            </div>
          </div>
        );
      default:
        return <div className="p-8 text-center text-slate-500 text-xs font-mono">FLOW_STAGE_PENDING</div>;
    }
  };

  const renderContent = () => {
    switch (activeCategory) {
      case HubCategory.FLOWS:
        return (
          <div className="lg:col-span-6 flex flex-col items-center justify-center space-y-16 animate-in fade-in duration-500">
            <WatchMock title="Hardware: Series Ultra X">
              {renderWatchContent()}
            </WatchMock>
            <div className="flex space-x-4 items-center bg-white/[0.03] p-4 rounded-full border border-white/5">
              {Object.values(FlowStep).map((step) => (
                <div key={step} className={`h-2.5 rounded-full transition-all duration-500 ${currentStep === step ? 'bg-primary w-12 shadow-[0_0_15px_#D97757]' : 'bg-slate-800 w-2.5'}`}></div>
              ))}
            </div>
          </div>
        );
      case HubCategory.RALPHIE:
        return (
          <div className="lg:col-span-12 py-10">
            <RalphieDashboard />
          </div>
        );
      case HubCategory.PRD:
        return (
          <div className="lg:col-span-12 py-10">
            <RalphiePRD />
          </div>
        );
      case HubCategory.FOUNDATIONS:
        return <div className="lg:col-span-12">{renderFoundations()}</div>;
      default:
        return (
          <div className="lg:col-span-12 text-center p-20 bg-white/5 rounded-[3rem] border border-white/10 w-full">
            <h2 className="text-2xl font-black text-white uppercase tracking-widest mb-4">Under Construction</h2>
            <p className="text-slate-500 text-sm max-w-md mx-auto">The interactive {activeCategory.toLowerCase()} module is being refined to meet the latest design protocol standards.</p>
          </div>
        );
    }
  };

  return (
    <div className="min-h-screen bg-[#050505] text-slate-100 flex flex-col items-center">
      <canvas ref={canvasRef} style={{ display: 'none' }} />
      
      <header className="w-full border-b border-white/[0.04] bg-black/80 backdrop-blur-2xl sticky top-0 z-50">
        <div className="max-w-[1600px] mx-auto px-10 py-6 flex items-center justify-between">
          <div className="flex items-center space-x-8">
            <div className="w-12 h-12 bg-primary rounded-2xl flex items-center justify-center shadow-2xl shadow-primary/20">
              <div className="w-6 h-6 bg-black rounded-[4px]"></div>
            </div>
            <div>
              <h1 className="text-[18px] font-black tracking-widest uppercase">Claude Watch</h1>
              <p className="text-[10px] text-slate-500 font-mono uppercase tracking-[0.2em]">{APP_VERSION} // System Design Lab</p>
            </div>
          </div>
          <div className="flex items-center space-x-2">
            {Object.values(HubCategory).map(cat => (
              <button 
                key={cat}
                onClick={() => setActiveCategory(cat)}
                className={`px-6 py-2.5 rounded-full text-[11px] font-black uppercase tracking-widest border transition-all ${activeCategory === cat ? 'bg-white text-black border-white' : 'bg-transparent text-slate-500 border-white/10 hover:border-white/20'}`}
              >
                {cat}
              </button>
            ))}
          </div>
        </div>
      </header>

      <main className="max-w-[1600px] w-full grid grid-cols-1 lg:grid-cols-12 gap-16 p-12 lg:p-16 flex-1">
        {/* Navigation Sidebar (Only for Flows) */}
        {activeCategory === HubCategory.FLOWS && (
          <div className="lg:col-span-3 space-y-12 animate-in slide-in-from-left-10 duration-500">
            <div className="space-y-6">
              <h2 className="text-[11px] font-black uppercase tracking-[0.5em] text-slate-700 border-b border-white/[0.05] pb-6 ml-1">Flow Controller</h2>
              <nav className="space-y-4">
                {Object.values(FlowStep).map((step) => (
                  <button
                    key={step}
                    onClick={() => { setCurrentStep(step); setAiFeedback(null); }}
                    className={`w-full text-left p-6 rounded-[2rem] transition-all border flex items-center justify-between group relative ${
                      currentStep === step 
                        ? 'bg-white border-white text-black font-black shadow-2xl scale-[1.04] z-10' 
                        : 'bg-[#0A0A0B] border-white/[0.06] text-slate-500 hover:border-white/20'
                    }`}
                  >
                    <span className="capitalize text-[14px] tracking-tight">{step.toLowerCase()}</span>
                    <div className={`w-2 h-2 rounded-full ${currentStep === step ? 'bg-primary' : 'bg-slate-800'}`}></div>
                  </button>
                ))}
              </nav>
            </div>
            <div className="bg-[#0A0A0B] border border-white/[0.06] p-10 rounded-[2.5rem] shadow-2xl">
               <div className="flex items-center space-x-3 mb-6">
                  <div className="w-1.5 h-1.5 bg-primary rounded-full animate-ping"></div>
                  <span className="text-[11px] font-black uppercase tracking-[0.3em] text-primary">Gemini Auditor</span>
               </div>
               {aiFeedback ? (
                 <p className="text-[15px] text-slate-300 italic leading-relaxed font-serif">"{aiFeedback}"</p>
               ) : (
                 <button 
                  onClick={handleAnalyze} disabled={isAnalyzing}
                  className="w-full py-4 bg-primary/10 hover:bg-primary/20 rounded-2xl text-[11px] font-black text-primary uppercase tracking-widest border border-primary/20 transition-all disabled:opacity-50"
                 >
                  {isAnalyzing ? 'Analyzing System...' : 'Run Lab Audit'}
                 </button>
               )}
            </div>
          </div>
        )}

        {/* Content Area */}
        {renderContent()}

        {/* Action Sidebar (Only for Flows) */}
        {activeCategory === HubCategory.FLOWS && (
          <div className="lg:col-span-3 space-y-12 animate-in slide-in-from-right-10 duration-500">
             <div className="bg-[#0A0A0B] border border-white/[0.06] rounded-[3rem] p-10 space-y-10">
              <h3 className="text-[11px] font-black uppercase tracking-[0.5em] text-slate-700 border-b border-white/[0.05] pb-6">Asset Pipeline</h3>
              <button 
                onClick={downloadAssets} disabled={isExporting}
                className="w-full bg-white text-black py-4 rounded-3xl text-[12px] font-black uppercase tracking-widest hover:bg-slate-200 transition-all shadow-xl shadow-white/5 flex items-center justify-center space-x-3 disabled:opacity-50"
              >
                {isExporting ? <div className="w-4 h-4 border-2 border-black border-t-transparent rounded-full animate-spin"></div> : <span>Export Core Assets</span>}
              </button>
              <div className="space-y-8 pt-4">
                <section className="space-y-3">
                  <h4 className="text-[13px] font-black text-white">Edge-to-Edge Glass</h4>
                  <p className="text-[13px] text-slate-500 leading-relaxed font-serif">Components must follow the bezel radius. All text is kept in the safe zone (8px margin).</p>
                </section>
                <div className="grid grid-cols-2 gap-6 pt-6 border-t border-white/[0.05]">
                  <div>
                    <div className="text-[9px] font-black uppercase text-slate-600 mb-1">Display</div>
                    <div className="text-[12px] font-mono text-primary font-black">LIPO-OLED</div>
                  </div>
                  <div>
                    <div className="text-[9px] font-black uppercase text-slate-600 mb-1">Refresh</div>
                    <div className="text-[12px] font-mono text-slate-300 font-black">120HZ LTPO</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      <footer className="w-full py-12 border-t border-white/[0.04] flex items-center justify-center">
         <span className="text-[9px] font-mono text-slate-800 uppercase tracking-[0.6em]">© ANTHROPIC // 2026 // DESIGN PROTOCOL</span>
      </footer>
    </div>
  );
};

export default App;
