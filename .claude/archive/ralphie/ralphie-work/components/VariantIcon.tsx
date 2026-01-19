import React from 'react';
import { VariantType } from '../types';
import MascotIcon from './MascotIcon';

interface VariantIconProps {
  type: VariantType;
  active?: boolean;
  small?: boolean;
  pixelSize?: number;
  shape?: 'circle' | 'squircle';
}

const VariantIcon: React.FC<VariantIconProps> = ({ 
  type, 
  active = false, 
  small = false, 
  pixelSize,
  shape = 'squircle'
}) => {
  const isCircle = shape === 'circle';
  
  // If pixelSize is provided, we assume it's a controlled sub-component and remove the wrapper background
  const containerClass = `flex items-center justify-center relative transition-all ${
    !pixelSize ? `aspect-square bg-card-dark ${isCircle ? 'rounded-full' : 'app-icon-squircle'}` : ''
  } ${
    !pixelSize ? (active ? 'ring-2 ring-primary shadow-lg ring-offset-2 ring-offset-background-light dark:ring-offset-background-dark' : 'ring-1 ring-transparent opacity-40 grayscale group-hover:grayscale-0 group-hover:opacity-100 group-hover:ring-slate-300 dark:group-hover:ring-slate-600') : ''
  }`;

  const renderContent = () => {
    switch (type) {
      case VariantType.TERMINAL:
        const termSize = pixelSize ? (pixelSize / 3) : 32;
        return <div style={{ width: termSize, height: termSize }} className={`rounded-sm ${active ? 'bg-primary' : 'bg-primary/40'}`}></div>;
      case VariantType.MASCOT:
        return <MascotIcon containerSize={pixelSize || (small ? 38.4 : 96)} isGrey={!active && small} isCircle={isCircle} />;
      case VariantType.ABSTRACT:
        const barWidth = pixelSize ? (pixelSize / 6) : 16;
        const barHeight = pixelSize ? (pixelSize / 2.4) : 40;
        return <div style={{ width: barWidth, height: barHeight }} className={`rounded-full rotate-45 ${active ? 'bg-primary' : 'bg-primary/40'}`}></div>;
      default:
        return null;
    }
  };

  return (
    <div className={containerClass} style={pixelSize ? { width: `${pixelSize}px`, height: `${pixelSize}px` } : {}}>
      {renderContent()}
    </div>
  );
};

export default VariantIcon;