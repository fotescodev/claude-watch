import React from 'react';

interface MascotIconProps {
  scale?: number;
  isGrey?: boolean;
  containerSize?: number;
  isCircle?: boolean;
  id?: string;
}

const MascotIcon: React.FC<MascotIconProps> = ({ 
  scale = 1, 
  isGrey = false, 
  containerSize = 96, 
  isCircle = true,
  id
}) => {
  // Base size for internal calculations
  const baseSize = 96;
  const baseScale = containerSize / baseSize;
  const finalScale = scale * baseScale;

  // Use the standard app icon squircle or a circle
  const borderRadius = isCircle ? 'rounded-full' : 'rounded-[22.5%]';

  return (
    <div 
      id={id}
      className={`relative flex flex-col items-center justify-center transition-all duration-500 overflow-visible ${borderRadius} ${isGrey ? 'bg-slate-700' : 'bg-[#D97757] shadow-[0_8px_24px_rgba(217,119,87,0.3)]'}`}
      style={{ 
        width: `${baseSize}px`, 
        height: `${baseSize}px`, 
        transform: `scale(${finalScale})`,
        transformOrigin: 'center center',
      }}
    >
      {/* 2026 Integrated Digital Crown Ear */}
      <div 
        className={`absolute top-[22px] -right-[1px] w-3.5 h-7 rounded-r-md border-l border-black/10 shadow-sm ${isGrey ? 'bg-slate-800' : 'bg-[#BF6446]'}`}
        style={{ 
          backgroundImage: 'repeating-linear-gradient(to bottom, transparent, transparent 3px, rgba(0,0,0,0.05) 3px, rgba(0,0,0,0.05) 4px)' 
        }}
      ></div>
      
      {/* Face Interface: Centered and proportional features */}
      <div className="flex flex-col items-center relative w-full h-full">
        {/* Eyes Row - Slightly above center */}
        <div className="absolute top-[35%] flex gap-4 items-center justify-center w-full">
          {/* Left Eye: Dot (Circle) */}
          <div className="w-2.5 h-2.5 bg-[#1A1A1A] rounded-full"></div>
          {/* Right Eye: Block (Square) */}
          <div className="w-3.5 h-3.5 bg-[#1A1A1A] rounded-[1px]"></div>
        </div>
        
        {/* Mouth: Semicircle Smile - Lowered and scaled down to be proportional */}
        <div className="absolute top-[58%] w-5 h-2.5 overflow-hidden">
           <div className="absolute top-[-100%] left-0 w-full h-[200%] border-[2.5px] border-[#1A1A1A] rounded-[50%]"></div>
        </div>
      </div>
    </div>
  );
};

export default MascotIcon;