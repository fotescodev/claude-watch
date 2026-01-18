
import React from 'react';

const Section: React.FC<{ title: string; children: React.ReactNode }> = ({ title, children }) => (
  <div className="mb-12 border-l-2 border-primary/20 pl-8 relative">
    <div className="absolute -left-[9px] top-0 w-4 h-4 bg-black border-2 border-primary rounded-full"></div>
    <h3 className="text-primary font-black text-sm uppercase tracking-[0.4em] mb-6">{title}</h3>
    <div className="text-slate-400 font-mono text-sm leading-relaxed space-y-4">
      {children}
    </div>
  </div>
);

const FeatureCard: React.FC<{ title: string; desc: string; tech: string }> = ({ title, desc, tech }) => (
  <div className="bg-white/[0.02] border border-white/10 p-6 rounded-sm hover:border-primary/40 transition-colors">
    <h4 className="text-white font-bold text-xs uppercase tracking-widest mb-2">{title}</h4>
    <p className="text-slate-400 text-xs mb-4 leading-relaxed">{desc}</p>
    <div className="text-[10px] font-bold text-cyan-400 uppercase tracking-tighter bg-cyan-500/10 px-2 py-1 inline-block">
      Tech: {tech}
    </div>
  </div>
);

const RalphiePRD: React.FC = () => {
  return (
    <div className="max-w-4xl mx-auto py-12 px-6 bg-black text-slate-300 font-mono animate-in fade-in duration-1000">
      <header className="mb-20 text-center">
        <div className="inline-block border border-primary px-4 py-1 text-[10px] font-black text-primary uppercase tracking-[0.5em] mb-4">
          Internal Document // CONFIDENTIAL
        </div>
        <h1 className="text-5xl font-black text-white tracking-tighter uppercase mb-4">Ralphie <span className="text-primary">v1.2</span></h1>
        <p className="text-slate-500 uppercase tracking-widest text-[11px]">Autonomous Orchestration Environment (AOE)</p>
        <div className="flex justify-center gap-8 mt-8 text-[9px] font-bold text-slate-700">
          <span>DATE: JAN 2026</span>
          <span>AUTH: ANTHROPIC_SYSTEMS</span>
          <span>REF: B-442-META</span>
        </div>
      </header>

      <Section title="01. Executive Summary">
        <p>
          Current AI coding loops suffer from "Contextual Blindness" and "Linear Latency." Ralphie v1.2 solves this by implementing a <span className="text-white font-bold">multi-shard cognitive architecture</span>. 
          Instead of a single stream of thought, Ralphie decomposes complex engineering tasks into topological graphs, executing them across parallel worker shards while a metacognitive supervisor optimizes for future efficiency.
        </p>
      </Section>

      <Section title="02. Core Orchestration Modes">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FeatureCard 
            title="Sequential Loop" 
            desc="Strict linear dependency. Used for high-risk operations where step B requires the specific verified outcome of step A."
            tech="Single-Chain Prompting + Verification Hooks"
          />
          <FeatureCard 
            title="Parallel Shards" 
            desc="Concurrent execution of heterogeneous tasks. UI components, logic layers, and tests are built simultaneously across N-threads."
            tech="Isolated Context Spawning + Conflict Resolvers"
          />
          <FeatureCard 
            title="Grouped Batching" 
            desc="Optimization for related minor edits. Updates multiple files in a single context window to preserve global token efficiency."
            tech="Batch-Inference + Multi-File Editing Buffers"
          />
          <FeatureCard 
            title="Thread Sharding" 
            desc="Decomposing a massive homogeneous task (e.g., refactoring 500 files) into identical worker instances."
            tech="Horizontal Scaling + Master-Worker Sync"
          />
        </div>
      </Section>

      <Section title="03. Metacognitive Feedback">
        <p>
          The "Smart-Loop" feature utilizes a <span className="text-cyan-400">Retrospective Agent</span> that analyzes the delta between predicted outcomes and actual results.
        </p>
        <ul className="list-disc list-inside space-y-4 text-xs ml-4">
          <li><span className="text-white">Self-Critique:</span> Every shard termination triggers a mandatory quality audit.</li>
          <li><span className="text-white">Heuristic Tuning:</span> If a shard stalls, the system automatically increases retry backoff and decreases temperature for the next iteration.</li>
          <li><span className="text-white">Knowledge Porting:</span> Successful patterns found in one shard are instantly indexed for use by other active shards.</li>
        </ul>
      </Section>

      <Section title="04. Design Philosophy">
        <div className="space-y-6 bg-white/[0.03] p-8 border border-white/10">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 bg-primary flex-shrink-0 flex items-center justify-center font-black text-black">TUI</div>
            <div>
              <h5 className="text-white text-xs font-bold uppercase mb-1">Density Over Whitespace</h5>
              <p className="text-[11px] leading-relaxed">Mission-critical environments require maximum information surface area. Every pixel must serve observability.</p>
            </div>
          </div>
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 bg-cyan-500 flex-shrink-0 flex items-center justify-center font-black text-black">OLED</div>
            <div>
              <h5 className="text-white text-xs font-bold uppercase mb-1">Pure Black Semantics</h5>
              <p className="text-[11px] leading-relaxed">Optimized for 2026 LTPO displays. High contrast reduces cognitive load during 12-hour engineering sprints.</p>
            </div>
          </div>
        </div>
      </Section>

      <Section title="05. Technical Stack">
        <div className="font-mono text-[10px] text-slate-500 bg-black border border-white/5 p-4 overflow-x-auto whitespace-pre">
{`{
  "engine": "Claude-3.5-Sonnet-Latest",
  "memory": "200K Context Window + Vector RAG",
  "parallelism": "N-Core Sharding Logic",
  "frontend": "React 19 + Tailwind CSS v4 + Framer Motion",
  "telemetry": "ASCII Sparkline Real-time Feed",
  "latency_target": "<1.2s Per Shard Turn"
}`}
        </div>
      </Section>

      <footer className="mt-20 pt-10 border-t border-white/10 text-center">
        <p className="text-[9px] text-slate-700 uppercase tracking-[0.8em]">END OF SPECIFICATION // SYSTEM_ACTIVE</p>
      </footer>
    </div>
  );
};

export default RalphiePRD;
