#!/usr/bin/env python3
"""
DeepSeek Terminal Chat Client (Enhanced with Glow Rendering)
- Ctrl+C to interrupt generation or exit.
- Stream characters first, then render with Glow.
- 支持系统提示词前缀，每次对话自动发送。

用法:
  python deepseek_chat_glow.py
  python deepseek_chat_glow.py --system-prompt "你是一个Python专家"

环境变量:
  DEEPSEEK_API_KEY       - API 密钥
  DEEPSEEK_SYSTEM_PROMPT - 系统提示词 (默认: 中文简洁回答)
"""

import os
import requests
import json
import sys
import subprocess
import readline
import tty
import termios
import unicodedata
from typing import Optional, Dict, List

# ANSI Color Codes
class Colors:
    BLUE = "\033[94m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"
    RESET = "\033[0m"
    DIM = "\033[2m"

class InputHandler:
    def __init__(self):
        self.history_file = os.path.expanduser("~/.deepseek_chat_history")
        self._load_history()

    def _load_history(self):
        try:
            if os.path.exists(self.history_file):
                readline.read_history_file(self.history_file)
        except Exception:
            pass

    def save_history(self):
        try:
            readline.write_history_file(self.history_file)
        except Exception:
            pass

# 系统提示词前缀，每次对话都会发送给 AI
# 可通过环境变量 DEEPSEEK_SYSTEM_PROMPT 覆盖
DEFAULT_SYSTEM_PROMPT = """你是一个位于linux终端的AI助手。请用中文回答问题，回答要简洁、准确、有条理。"""

class DeepSeekChat:
    def __init__(self, api_key: Optional[str] = None, system_prompt: Optional[str] = None):
        self.api_key = api_key or os.getenv("DEEPSEEK_API_KEY")
        if not self.api_key:
            raise ValueError("API key not found. Set DEEPSEEK_API_KEY environment variable.")

        self.base_url = "https://api.deepseek.com/chat/completions"
        self.conversation_history: List[Dict[str, str]] = []
        self.input_handler = InputHandler()
        self.is_generating = False
        self.system_prompt = system_prompt or os.getenv("DEEPSEEK_SYSTEM_PROMPT", DEFAULT_SYSTEM_PROMPT)

    def _print_system(self, text: str):
        print(f"{Colors.YELLOW}{text}{Colors.RESET}")

    def _print_error(self, text: str):
        print(f"{Colors.RED}{Colors.BOLD}❌ {text}{Colors.RESET}")

    def read_multiline(self, prompt: str) -> str:
        """读取多行输入：Enter 发送，Ctrl+J 换行，粘贴内容自动识别。"""
        print(prompt, end="", flush=True)

        lines = [""]
        cursor_y = 0  # 当前行索引
        cursor_x = 0  # 当前行中的光标位置（字符索引）
        # 前缀定义：第一行用 prompt，后续行用等宽缩进
        prompt_str = f"{Colors.CYAN}{Colors.BOLD}👤 You: {Colors.RESET}"
        prompt_len = 8  # "👤 You: " 的显示宽度（👤=2 + " You: "=6）
        cont_prefix = " " * prompt_len  # 续行缩进

        def get_display_width(s: str) -> int:
            """计算字符串的终端显示宽度"""
            width = 0
            for ch in s:
                if unicodedata.east_asian_width(ch) in ('F', 'W'):
                    width += 2
                else:
                    width += 1
            return width

        def get_prefix_width() -> int:
            """获取当前行前缀的显示宽度"""
            return prompt_len

        def redraw_current_line():
            """重新绘制当前行，将光标放在正确位置"""
            prefix = prompt_str if cursor_y == 0 else cont_prefix
            line = lines[cursor_y]
            # 计算光标应该在的列位置（前缀宽度 + 光标前文本的显示宽度）
            text_before_cursor = line[:cursor_x]
            cursor_col = get_prefix_width() + get_display_width(text_before_cursor)
            # 清除当前行并重绘
            sys.stdout.write(f"\r\x1b[K{prefix}{line}")
            # 将光标移动到正确位置
            total_width = get_prefix_width() + get_display_width(line)
            if cursor_col < total_width:
                sys.stdout.write(f"\033[{total_width - cursor_col}D")
            sys.stdout.flush()

        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        # 启用括号粘贴模式
        sys.stdout.write("\x1b[?2004h")
        sys.stdout.flush()
        try:
            tty.setraw(fd)
            while True:
                ch = os.read(fd, 32).decode("utf-8", errors="replace")

                i = 0
                while i < len(ch):
                    c = ch[i]

                    # 括号粘贴开始
                    if ch[i:].startswith("\x1b[200~"):
                        # 读取粘贴内容直到 \x1b[201~]
                        paste_end = ch.find("\x1b[201~", i + 6)
                        if paste_end != -1:
                            paste_content = ch[i + 6:paste_end]
                            i = paste_end + 6  # 跳过结束标记
                        else:
                            # 跨包，继续读取
                            paste_content = ch[i + 6:]
                            while True:
                                more = os.read(fd, 1024).decode("utf-8", errors="replace")
                                end = more.find("\x1b[201~")
                                if end != -1:
                                    paste_content += more[:end]
                                    break
                                paste_content += more
                            i = len(ch)  # 当前缓冲区已消费完

                        # 还原终端以便打印
                        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                        # 将粘贴内容按行插入
                        paste_lines = paste_content.split("\r")
                        if len(paste_lines) == 1:
                            paste_lines = paste_content.split("\n")
                        # 合并 \r\n
                        cleaned = []
                        for pl in paste_lines:
                            cleaned.extend(pl.split("\n"))
                        paste_lines = [p for p in cleaned if p != ""]
                        if not paste_lines:
                            paste_lines = [""]

                        # 在光标位置插入粘贴内容
                        before = lines[cursor_y][:cursor_x]
                        after = lines[cursor_y][cursor_x:]
                        lines[cursor_y] = before + paste_lines[0]
                        cursor_x += len(paste_lines[0])
                        for extra in paste_lines[1:]:
                            cursor_y += 1
                            lines.insert(cursor_y, extra)
                            cursor_x = len(extra)
                        # 如果有剩余的 after 内容，添加到最后一行
                        if after:
                            lines[cursor_y] += after
                        # 重新显示所有行
                        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                        sys.stdout.write(f"\r\x1b[K")
                        for idx, line in enumerate(lines):
                            if idx > 0:
                                sys.stdout.write("\n")
                            prefix = prompt_str if idx == 0 else cont_prefix
                            sys.stdout.write(f"\r\x1b[K{prefix}{line}")
                        # 将光标放到正确位置
                        redraw_current_line()
                        tty.setraw(fd)
                        continue

                    # Ctrl+J (0x0A) → 换行
                    if c == "\n":
                        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                        # 将光标后的内容移到新行
                        after = lines[cursor_y][cursor_x:]
                        lines[cursor_y] = lines[cursor_y][:cursor_x]
                        cursor_y += 1
                        lines.insert(cursor_y, after)
                        cursor_x = 0
                        # 重新绘制当前行和新行
                        sys.stdout.write(f"\n\r\x1b[K{cont_prefix}{after}")
                        # 如果新行有内容，将光标移到行首
                        if after:
                            sys.stdout.write(f"\033[{get_display_width(after)}D")
                        sys.stdout.flush()
                        tty.setraw(fd)
                        i += 1
                        continue

                    # Enter (0x0D) → 发送
                    if c == "\r":
                        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                        sys.stdout.write("\n")
                        sys.stdout.flush()
                        result = "\n".join(lines).strip()
                        return result

                    # Ctrl+C
                    if c == "\x03":
                        raise KeyboardInterrupt

                    # Ctrl+D (空行时退出)
                    if c == "\x04":
                        if all(line == "" for line in lines):
                            raise EOFError
                        i += 1
                        continue

                    # Backspace (0x7F) 或 Ctrl+H (0x08)
                    if c in ("\x7f", "\x08"):
                        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                        if cursor_x > 0:
                            # 删除光标前的字符
                            deleted_char = lines[cursor_y][cursor_x - 1]
                            lines[cursor_y] = lines[cursor_y][:cursor_x - 1] + lines[cursor_y][cursor_x:]
                            cursor_x -= 1
                            # 重新绘制当前行
                            redraw_current_line()
                        elif cursor_y > 0:
                            # 当前行开头，合并到上一行
                            after = lines[cursor_y]
                            lines.pop(cursor_y)
                            cursor_y -= 1
                            cursor_x = len(lines[cursor_y])
                            lines[cursor_y] += after
                            # 重新绘制
                            redraw_current_line()
                        sys.stdout.flush()
                        tty.setraw(fd)
                        i += 1
                        continue

                    # ESC 序列 (方向键等)
                    if c == "\x1b":
                        if i + 1 < len(ch) and ch[i + 1] == "[":
                            # CSI 序列: ESC [ ... letter
                            j = i + 2
                            while j < len(ch) and not ch[j].isalpha():
                                j += 1
                            if j < len(ch):
                                seq = ch[i + 2:j + 1]
                                letter = ch[j]
                                termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                                # 处理方向键
                                if letter == 'D':  # 左箭头
                                    if cursor_x > 0:
                                        cursor_x -= 1
                                        # 计算需要移动的显示宽度
                                        char = lines[cursor_y][cursor_x]
                                        char_width = 2 if unicodedata.east_asian_width(char) in ('F', 'W') else 1
                                        sys.stdout.write(f"\033[{char_width}D")
                                        sys.stdout.flush()
                                elif letter == 'C':  # 右箭头
                                    if cursor_x < len(lines[cursor_y]):
                                        char = lines[cursor_y][cursor_x]
                                        char_width = 2 if unicodedata.east_asian_width(char) in ('F', 'W') else 1
                                        cursor_x += 1
                                        sys.stdout.write(f"\033[{char_width}C")
                                        sys.stdout.flush()
                                elif letter == 'A':  # 上箭头
                                    if cursor_y > 0:
                                        cursor_y -= 1
                                        cursor_x = min(cursor_x, len(lines[cursor_y]))
                                        redraw_current_line()
                                elif letter == 'B':  # 下箭头
                                    if cursor_y < len(lines) - 1:
                                        cursor_y += 1
                                        cursor_x = min(cursor_x, len(lines[cursor_y]))
                                        redraw_current_line()
                                elif letter == 'H':  # Home 键
                                    cursor_x = 0
                                    redraw_current_line()
                                elif letter == 'F':  # End 键
                                    cursor_x = len(lines[cursor_y])
                                    redraw_current_line()
                                tty.setraw(fd)
                            i = j + 1
                            continue
                        i += 2
                        continue

                    # 普通可打印字符
                    if c.isprintable():
                        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                        # 在光标位置插入字符
                        lines[cursor_y] = lines[cursor_y][:cursor_x] + c + lines[cursor_y][cursor_x:]
                        cursor_x += 1
                        # 重新绘制当前行
                        redraw_current_line()
                        tty.setraw(fd)

                    i += 1

        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
            # 关闭括号粘贴模式
            sys.stdout.write("\x1b[?2004l")
            sys.stdout.flush()

    def _render_with_glow(self, text: str):
        """将文本传递给 glow 进行渲染"""
        try:
            # 检查 glow 是否在系统路径中
            # -a 参数可以让 glow 自动适应终端宽度
            process = subprocess.Popen(
                ['glow', '-'], 
                stdin=subprocess.PIPE, 
                stdout=sys.stdout, 
                stderr=subprocess.PIPE,
                text=True
            )
            process.communicate(input=text)
        except FileNotFoundError:
            # 如果没安装 glow，则回退到普通绿色文本
            print(f"{Colors.GREEN}{text}{Colors.RESET}")
            print(f"\n{Colors.DIM}(Tip: Install 'glow' to get better markdown rendering){Colors.RESET}")

    def send_message(self, message: str, stream: bool = True):
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }

        self.conversation_history.append({"role": "user", "content": message})

        # 构建带系统提示词的消息列表（不污染 conversation_history）
        messages = [{"role": "system", "content": self.system_prompt}] + self.conversation_history

        payload = {
            "model": "deepseek-chat",
            "messages": messages,
            "stream": stream,
            "temperature": 0.7,
        }

        try:
            self.is_generating = True
            if stream:
                return self._stream_response(headers, payload)
            else:
                return self._get_complete_response(headers, payload)
        except requests.exceptions.RequestException as e:
            self._print_error(f"Network error: {e}")
            return None
        finally:
            self.is_generating = False

    def _get_complete_response(self, headers: Dict, payload: Dict) -> Optional[str]:
        response = requests.post(self.base_url, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
        ai_response = data["choices"][0]["message"]["content"]
        self.conversation_history.append({"role": "assistant", "content": ai_response})
        
        self._render_with_glow(ai_response)
        return ai_response

    def _stream_response(self, headers: Dict, payload: Dict) -> Optional[str]:
        full_response = ""
        try:
            response = requests.post(self.base_url, headers=headers, json=payload, stream=True)
            response.raise_for_status()

            # 阶段 1: 流式显示原始文本 (用暗色/淡色区分流式过程)
            print(f"{Colors.DIM}", end="", flush=True)
            
            for line in response.iter_lines():
                if not line: continue
                
                line_str = line.decode("utf-8")
                if line_str.startswith("data: "):
                    data_content = line_str[6:]
                    if data_content == "[DONE]":
                        break

                    try:
                        json_data = json.loads(data_content)
                        delta = json_data["choices"][0].get("delta", {})
                        if "content" in delta:
                            content = delta["content"]
                            full_response += content
                            print(content, end="", flush=True)
                    except json.JSONDecodeError:
                        continue
            
            print(f"{Colors.RESET}") # 结束流式颜色
            
            # 阶段 2: 渲染最终 Markdown 内容
            if full_response:
                # 打印一个简单的分割提示
                print(f"{Colors.YELLOW}--- Rendered Output ---{Colors.RESET}")
                self._render_with_glow(full_response)
                self.conversation_history.append({"role": "assistant", "content": full_response})
            
            return full_response

        except KeyboardInterrupt:
            print(f"\n{Colors.YELLOW}[Generation Interrupted]{Colors.RESET}")
            if full_response:
                self.conversation_history.append({"role": "assistant", "content": full_response + " [Interrupted]"})
                # 即使中断也尝试渲染已有的部分
                self._render_with_glow(full_response)
            return None

    def chat_loop(self):
        print(f"{Colors.CYAN}{Colors.BOLD}{'='*50}")
        print(f"🤖 DeepSeek Terminal Chat (Glow Enabled)")
        print(f"{'='*50}{Colors.RESET}")
        print(f"{Colors.DIM}Enter=发送 | Ctrl+J=换行 | 粘贴自动识别 | quit/exit=退出 | clear=清空历史{Colors.RESET}")
        print(f"{Colors.DIM}📝 System Prompt: {self.system_prompt}{Colors.RESET}")

        while True:
            try:
                prompt = f"\n{Colors.CYAN}{Colors.BOLD}👤 You: {Colors.RESET}"
                user_input = self.read_multiline(prompt).strip()

                if not user_input:
                    continue

                if user_input.lower() in ["quit", "exit", "bye"]:
                    print(f"{Colors.YELLOW}Goodbye!{Colors.RESET}")
                    break

                if user_input.lower() == "clear":
                    self.conversation_history.clear()
                    self._print_system("🗑️ Conversation history cleared!")
                    continue

                print(f"{Colors.GREEN}{Colors.BOLD}🤖 DeepSeek:{Colors.RESET} ", end="", flush=True)
                self.send_message(user_input, stream=True)

            except KeyboardInterrupt:
                print(f"\n{Colors.YELLOW}Exiting...{Colors.RESET}")
                break
            except EOFError:
                break

        self.input_handler.save_history()

def main():
    api_key = None
    system_prompt = None

    # 解析命令行参数
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--api-key" and i + 1 < len(args):
            api_key = args[i + 1]
            i += 2
        elif args[i] == "--system-prompt" and i + 1 < len(args):
            system_prompt = args[i + 1]
            i += 2
        else:
            i += 1

    try:
        chat_client = DeepSeekChat(api_key=api_key, system_prompt=system_prompt)
        chat_client.chat_loop()
    except ValueError as e:
        print(f"{Colors.RED}❌ Error: {e}{Colors.RESET}")
        sys.exit(1)

if __name__ == "__main__":
    main()
