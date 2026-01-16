import { useState } from 'react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/app/components/ui/tabs';
import { Card } from '@/app/components/ui/card';
import { Badge } from '@/app/components/ui/badge';
import { Check, X, Bell, Zap, WifiOff, AlertCircle } from 'lucide-react';
import { DesignSystem } from '@/app/components/DesignSystem';
import { Components } from '@/app/components/Components';
import { WatchMockups } from '@/app/components/WatchMockups';
import { Recommendation } from '@/app/components/Recommendation';

export default function App() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-neutral-950 via-neutral-900 to-neutral-950">
      {/* Header */}
      <header className="border-b border-neutral-800 bg-black/40 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-6 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-white mb-1">Claude Watch UX Redesign</h1>
              <p className="text-neutral-400">Optimized for sub-3-second approval workflows</p>
            </div>
            <Badge variant="outline" className="bg-orange-500/10 text-orange-400 border-orange-500/30 px-4 py-2 text-sm">
              watchOS 10+
            </Badge>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-6 py-12">
        <Tabs defaultValue="recommendation" className="w-full">
          <TabsList className="grid w-full grid-cols-4 bg-neutral-900/50 border border-neutral-800 mb-8">
            <TabsTrigger value="recommendation">Recommendation</TabsTrigger>
            <TabsTrigger value="design-system">Design System</TabsTrigger>
            <TabsTrigger value="components">Components</TabsTrigger>
            <TabsTrigger value="mockups">Watch Screens</TabsTrigger>
          </TabsList>

          <TabsContent value="recommendation" className="space-y-6">
            <Recommendation />
          </TabsContent>

          <TabsContent value="design-system" className="space-y-6">
            <DesignSystem />
          </TabsContent>

          <TabsContent value="components" className="space-y-6">
            <Components />
          </TabsContent>

          <TabsContent value="mockups" className="space-y-6">
            <WatchMockups />
          </TabsContent>
        </Tabs>
      </main>
    </div>
  );
}
