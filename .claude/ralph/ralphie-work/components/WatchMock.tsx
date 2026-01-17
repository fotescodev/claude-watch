
import React from 'react';

interface WatchMockProps {
  children: React.ReactNode;
  title?: string;
  crownColor?: string;
}

const WatchMock: React.FC<WatchMockProps> = ({ children, title, crownColor = "#BF6446" }) => {
  return (
    <div className="flex flex-col items-center space-y-6">
      {title && <span className="text-[10px] font-black uppercase tracking-[0.4em] text-slate-500 opacity-50">{title}</span>}
      <div className="relative group">
        {/* Hardware Reflection Glow */}
        <div className="absolute -inset-4 bg-primary/5 blur-3xl rounded-full opacity-50 group-hover:opacity-80 transition-opacity"></div>
        
        {/* Outer Titanium/Glass Case */}
        <div className="w-[184px] h-[224px] bg-gradient-to-br from-[#2C2C2E] via-[#1C1C1E] to-[#0A0A0B] rounded-[3rem] p-[3px] shadow-[0_40px_80px_-20px_rgba(0,0,0,0.8)] relative overflow-hidden flex items-center justify-center border border-white/10">
          
          {/* Subtle Metallic Bezel Detail */}
          <div className="absolute inset-[2px] border border-white/5 rounded-[2.9rem] pointer-events-none"></div>
          
          {/* Internal Display Container (Edge-to-Edge) */}
          <div className="w-full h-full bg-black rounded-[2.75rem] relative overflow-hidden flex flex-col shadow-inner">
            {/* Screen Depth/Reflection Mask */}
            <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-white/[0.02] to-white/[0.05] pointer-events-none z-10"></div>
            
            {/* The Actual Content - No forced padding to allow true edge-to-edge designs */}
            <div className="relative z-0 w-full h-full flex flex-col">
              {children}
            </div>
          </div>
        </div>

        {/* 2026 Digital Crown - Precision Machined Look */}
        <div 
          className="absolute -right-[4px] top-[22%] w-[10px] h-12 rounded-r-md border-l border-black/40 shadow-xl z-20 transition-transform active:scale-95 cursor-pointer"
          style={{ 
            backgroundColor: crownColor, 
            backgroundImage: 'repeating-linear-gradient(to bottom, transparent, transparent 2px, rgba(0,0,0,0.2) 2px, rgba(0,0,0,0.2) 4px)' 
          }}
        >
          {/* Subtle Highlight on Crown */}
          <div className="absolute inset-0 bg-gradient-to-r from-white/20 to-transparent rounded-r-md"></div>
        </div>

        {/* Side Button - Flush but tactile */}
        <div className="absolute -right-[2px] bottom-[30%] w-[6px] h-16 bg-[#2C2C2E] rounded-r-sm border-l border-black/40 z-10 shadow-lg"></div>
        
        {/* Antenna Band Line (Precision detail) */}
        <div className="absolute left-1/2 -top-[1px] -translate-x-1/2 w-8 h-[1px] bg-white/5"></div>
      </div>
    </div>
  );
};

export default WatchMock;
