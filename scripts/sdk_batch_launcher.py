#!/usr/bin/env python3
"""
Opencode SDK Batch Launcher
============================

This script demonstrates how to use the Opencode SDK to launch multiple
agent sessions with dynamically specified models.

Usage:
    python sdk_batch_launcher.py --model "openai/gpt-5.2-codex" --projects projects.txt
    python sdk_batch_launcher.py --model "anthropic/claude-sonnet-4-20250514" --command "/plan"

Requirements:
    pip install opencode-sdk asyncio aiofiles

Environment Variables:
    OPENCODE_MODEL          - Default model to use
    OPENCODE_SMALL_MODEL    - Model for quick tasks
    OPENCODE_API_KEY        - API key for Opencode subscription
"""

import os
import sys
import asyncio
import argparse
import subprocess
from pathlib import Path
from typing import List, Optional
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor

# Try to import opencode SDK (may not be installed)
try:
    from opencode import OpenCode, Session
    HAS_SDK = True
except ImportError:
    HAS_SDK = False
    print("Warning: opencode-sdk not installed. Using subprocess fallback.")


@dataclass
class ProjectConfig:
    """Configuration for a single project."""
    path: Path
    name: str
    model: str
    command: Optional[str] = None


class BatchLauncher:
    """
    Batch launcher for Opencode sessions.
    
    Supports both SDK-based and subprocess-based launching.
    """
    
    def __init__(
        self,
        model: str = "openai/gpt-5.2-codex",
        small_model: Optional[str] = None,
        max_workers: int = 4
    ):
        self.model = model
        self.small_model = small_model or model
        self.max_workers = max_workers
        self.sessions: List[Session] = []
    
    def set_environment(self):
        """Set environment variables for Opencode."""
        os.environ["OPENCODE_MODEL"] = self.model
        os.environ["OPENCODE_SMALL_MODEL"] = self.small_model
        os.environ["OPENCODE_PLAN_MODEL"] = self.model
    
    def load_projects(self, projects_file: str) -> List[ProjectConfig]:
        """Load project paths from a file."""
        projects = []
        with open(projects_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                # Expand ~ to home directory
                path = Path(line).expanduser()
                if path.exists() and path.is_dir():
                    projects.append(ProjectConfig(
                        path=path,
                        name=path.name,
                        model=self.model
                    ))
                else:
                    print(f"Warning: Directory not found: {path}")
        
        return projects
    
    async def launch_with_sdk(
        self,
        project: ProjectConfig,
        command: Optional[str] = None
    ) -> Optional[Session]:
        """Launch Opencode session using SDK."""
        if not HAS_SDK:
            return None
        
        try:
            client = OpenCode(
                model=project.model,
                working_directory=str(project.path)
            )
            
            session = await client.create_session()
            
            if command:
                await session.send_command(command)
            
            self.sessions.append(session)
            print(f"✓ SDK session started: {project.name}")
            return session
            
        except Exception as e:
            print(f"✗ SDK launch failed for {project.name}: {e}")
            return None
    
    def launch_with_subprocess(
        self,
        project: ProjectConfig,
        command: Optional[str] = None
    ) -> Optional[subprocess.Popen]:
        """Launch Opencode using subprocess (tmux)."""
        try:
            # Set environment
            env = os.environ.copy()
            env["OPENCODE_MODEL"] = project.model
            env["OPENCODE_SMALL_MODEL"] = self.small_model
            
            # Build command
            if command:
                cmd = f"opencode '{command}'"
            else:
                cmd = "opencode"
            
            # Create tmux window
            session_name = "opencode-sdk-batch"
            
            # Check if session exists
            result = subprocess.run(
                ["tmux", "has-session", "-t", session_name],
                capture_output=True
            )
            
            if result.returncode != 0:
                # Create new session
                subprocess.run([
                    "tmux", "new-session", "-d", "-s", session_name,
                    "-n", project.name, "-c", str(project.path)
                ], env=env)
            else:
                # Create new window in existing session
                subprocess.run([
                    "tmux", "new-window", "-t", session_name,
                    "-n", project.name, "-c", str(project.path)
                ], env=env)
            
            # Send opencode command
            subprocess.run([
                "tmux", "send-keys", "-t", f"{session_name}:{project.name}",
                f"export OPENCODE_MODEL='{project.model}' && {cmd}", "C-m"
            ])
            
            print(f"✓ Subprocess session started: {project.name}")
            return True
            
        except Exception as e:
            print(f"✗ Subprocess launch failed for {project.name}: {e}")
            return None
    
    async def launch_batch(
        self,
        projects: List[ProjectConfig],
        command: Optional[str] = None,
        use_sdk: bool = True
    ):
        """Launch multiple Opencode sessions in parallel."""
        self.set_environment()
        
        if use_sdk and HAS_SDK:
            # Use SDK for async launching
            tasks = [
                self.launch_with_sdk(project, command)
                for project in projects
            ]
            await asyncio.gather(*tasks)
        else:
            # Use subprocess with thread pool
            with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
                futures = [
                    executor.submit(self.launch_with_subprocess, project, command)
                    for project in projects
                ]
                for future in futures:
                    future.result()
        
        print(f"\n✓ Batch launch complete: {len(projects)} projects")
        if not use_sdk or not HAS_SDK:
            print("Attach to session: tmux attach -t opencode-sdk-batch")
    
    async def close_all(self):
        """Close all SDK sessions."""
        for session in self.sessions:
            try:
                await session.close()
            except Exception:
                pass
        self.sessions.clear()


class ModelPresets:
    """Predefined model configurations."""
    
    CODEX_52 = "openai/gpt-5.2-codex"
    GPT_4O = "openai/gpt-4o"
    O1 = "openai/o1"
    O3 = "openai/o3"
    
    CLAUDE_SONNET = "anthropic/claude-sonnet-4-20250514"
    CLAUDE_OPUS = "anthropic/claude-opus-4-20250514"
    
    GEMINI_PRO = "google/gemini-2.5-pro"
    GEMINI_FLASH = "google/gemini-2.5-flash"
    
    GLM_47 = "z-ai/glm-4.7"
    
    DEEPSEEK_CHAT = "deepseek/deepseek-chat"
    DEEPSEEK_CODER = "deepseek/deepseek-coder"
    
    MISTRAL_LARGE = "mistral/mistral-large-latest"
    CODESTRAL = "mistral/codestral-latest"


def main():
    parser = argparse.ArgumentParser(
        description="Opencode SDK Batch Launcher",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Launch with Codex 5.2 (default)
  python sdk_batch_launcher.py -p projects.txt

  # Launch with Claude Sonnet
  python sdk_batch_launcher.py -m "anthropic/claude-sonnet-4-20250514" -p projects.txt

  # Launch with specific command
  python sdk_batch_launcher.py -p projects.txt -c "/plan"

  # Use subprocess mode (no SDK required)
  python sdk_batch_launcher.py -p projects.txt --no-sdk

Available Model Presets:
  OpenAI:    openai/gpt-5.2-codex, openai/gpt-4o, openai/o1, openai/o3
  Anthropic: anthropic/claude-sonnet-4-20250514, anthropic/claude-opus-4-20250514
  Google:    google/gemini-2.5-pro, google/gemini-2.5-flash
  Z.AI:      z-ai/glm-4.7
  DeepSeek:  deepseek/deepseek-chat, deepseek/deepseek-coder
  Mistral:   mistral/mistral-large-latest, mistral/codestral-latest
        """
    )
    
    parser.add_argument(
        "-m", "--model",
        default=os.environ.get("OPENCODE_MODEL", ModelPresets.CODEX_52),
        help="Model to use (default: openai/gpt-5.2-codex)"
    )
    parser.add_argument(
        "-p", "--projects",
        required=True,
        help="File containing project paths (one per line)"
    )
    parser.add_argument(
        "-c", "--command",
        help="Opencode command to run (e.g., /plan, /tdd)"
    )
    parser.add_argument(
        "-w", "--workers",
        type=int,
        default=4,
        help="Number of parallel workers (default: 4)"
    )
    parser.add_argument(
        "--no-sdk",
        action="store_true",
        help="Use subprocess mode instead of SDK"
    )
    
    args = parser.parse_args()
    
    # Create launcher
    launcher = BatchLauncher(
        model=args.model,
        max_workers=args.workers
    )
    
    # Load projects
    projects = launcher.load_projects(args.projects)
    if not projects:
        print("Error: No valid projects found")
        sys.exit(1)
    
    print(f"Model: {args.model}")
    print(f"Projects: {len(projects)}")
    print(f"Workers: {args.workers}")
    print()
    
    # Launch
    asyncio.run(launcher.launch_batch(
        projects,
        command=args.command,
        use_sdk=not args.no_sdk
    ))


if __name__ == "__main__":
    main()
