// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Hello is a simple hello, world demonstration web server.
//
// It serves version information on /version and answers
// any other request like /name by saying "Hello, name!".
//
// See golang.org/x/example/outyet for a more sophisticated server.

// for ((i=0; i<24*3600; i+=60)); do echo "Refreshed at $(date)"; curl -sL https://9000-firebase-go-1746831783590.cluster-joak5ukfbnbyqspg4tewa33d24.cloudworkstations.dev/alive?monospaceUid=458426; sleep 60; done

package main

import (
	"encoding/base64"
	"fmt"
	"html"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

var (
	addr = "localhost:9002"
)

func main() {
	// Register handlers.
	// / runs the script with directory and process check and returns HTML.
	// /node runs the script with process check and returns Base64-encoded node info.
	http.HandleFunc("/", runScript)
	http.HandleFunc("/node", runScript2)
	http.HandleFunc("/alive", alive)

	log.Printf("serving http://%s\n", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}

func checkProcesses() (bool, error) {
	// 定义变量，作用域为整个函数
	var singBoxRunning, cloudflaredRunning bool

	// 检查 sing-box 进程
	singBoxCmd := exec.Command("pgrep", "-f", "./nixag/sing-box run")
	singBoxOutput, err := singBoxCmd.CombinedOutput()
	if err != nil {
		log.Printf("pgrep sing-box error: %v, output: %s", err, string(singBoxOutput))
		singBoxRunning = false
	} else {
		singBoxRunning = len(strings.TrimSpace(string(singBoxOutput))) > 0
		log.Printf("singBoxRunning: %v, singBoxOutput: %s", singBoxRunning, string(singBoxOutput))
	}

	// 检查 cloudflared 进程
	cloudflaredCmd := exec.Command("pgrep", "-f", "./nixag/cloudflared tunnel")
	cloudflaredOutput, err := cloudflaredCmd.CombinedOutput()
	if err != nil {
		log.Printf("pgrep cloudflared error: %v, output: %s", err, string(cloudflaredOutput))
		cloudflaredRunning = false
	} else {
		cloudflaredRunning = len(strings.TrimSpace(string(cloudflaredOutput))) > 0
		log.Printf("cloudflaredRunning: %v, cloudflaredOutput: %s", cloudflaredRunning, string(cloudflaredOutput))
	}

	areProcessesRunning := singBoxRunning && cloudflaredRunning
	log.Printf("areProcessesRunning: %v", areProcessesRunning)
	return areProcessesRunning, nil
}

func runScript(w http.ResponseWriter, r *http.Request) {
	// 设置网页响应头
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, "<!DOCTYPE html>\n<html>\n<head>\n<title>Script Output</title>\n</head>\n<body>\n")
	fmt.Fprintf(w, "<h2>Script Execution Result</h2>\n")

	// 检查 nixag 目录是否存在
	_, dirErr := os.Stat("nixag")
	dirExists := !os.IsNotExist(dirErr)

	log.Printf("dirExists: %v", dirExists)

	// 检查 sing-box 和 cloudflared 进程
	areProcessesRunning, err := checkProcesses()
	if err != nil {
		fmt.Fprintf(w, "<p>Error checking processes: %v</p>\n", html.EscapeString(err.Error()))
		fmt.Fprintf(w, "</body>\n</html>")
		return
	}

	if !dirExists || (dirExists && !areProcessesRunning) {
		delCmd := exec.Command("bash", "-c", "nix=y bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) del")
		_, delErr := delCmd.CombinedOutput()
		if delErr != nil {
			http.Error(w, "Failed to execute script (del)", http.StatusInternalServerError)
			return
		}

		fmt.Fprintf(w, "<h3>1. Output of the script (nix=y bash ...):</h3>\n<pre>\n")
		cmd := exec.Command("bash", "-c", "nix=y bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)")
		output, err := cmd.CombinedOutput()
		if err != nil {
			fmt.Fprintf(w, "Error executing script: %v\n", html.EscapeString(err.Error()))
			fmt.Fprintf(w, "Output (if any):\n%s\n", html.EscapeString(string(output)))
		} else {
			fmt.Fprintf(w, "Script executed successfully:\n%s\n", html.EscapeString(string(output)))
		}
		fmt.Fprintf(w, "</pre>\n")
	} else {
		// 目录存在且进程都在运行，跳过脚本执行
		fmt.Fprintf(w, "<p>nixag directory exists and processes are running, skipping script execution.</p>\n")
	}

	// 第二部分：执行 cat nixag/jh.txt 并显示输出
	fmt.Fprintf(w, "<h3>2. Output of 'cat nixag/jh.txt':</h3>\n<pre>\n")
	catCmd := exec.Command("cat", "nixag/jh.txt")
	catOutput, catErr := catCmd.CombinedOutput()
	if catErr != nil {
		fmt.Fprintf(w, "Error executing 'cat nixag/jh.txt': %v\n", html.EscapeString(catErr.Error()))
		fmt.Fprintf(w, "Output (if any):\n%s\n", html.EscapeString(string(catOutput)))
	} else {
		fmt.Fprintf(w, "%s\n", html.EscapeString(string(catOutput)))
	}
	fmt.Fprintf(w, "</pre>\n")


	fmt.Fprintf(w, "keep alive:<br>")
	fmt.Fprintf(w, "for ((i=0; i<24*3600; i+=60)); do echo \"Refreshed at $(date)\"; curl -sL alive_url; sleep 60; done\n")
	// 结束 HTML 页面
	fmt.Fprintf(w, "</body>\n</html>")

	// 检查 sing-box 和 cloudflared 进程
	checkProcesses()
}

func runScript2(w http.ResponseWriter, r *http.Request) {
	// 检查 nixag 目录是否存在
	_, dirErr := os.Stat("nixag")
	dirExists := !os.IsNotExist(dirErr)
	log.Printf("dirExists: %v, dirErr: %v", dirExists, dirErr)

	// 检查 sing-box 和 cloudflared 进程
	areProcessesRunning, err := checkProcesses()
	if err != nil {
		http.Error(w, "Failed to check processes", http.StatusInternalServerError)
		return
	}
	log.Printf("areProcessesRunning: %v", areProcessesRunning)

	if !dirExists || !areProcessesRunning {
		log.Printf("Condition triggered: !dirExists || !areProcessesRunning")
		// 进程未全部运行或目录不存在，执行带 del 参数和不带 del 参数的脚本
		delCmd := exec.Command("bash", "-c", "nix=y bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) del")
		_, delErr := delCmd.CombinedOutput()
		if delErr != nil {
			http.Error(w, "Failed to execute script (del)", http.StatusInternalServerError)
			return
		}

		cmd := exec.Command("bash", "-c", "nix=y bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)")
		_, err := cmd.CombinedOutput()
		if err != nil {
			http.Error(w, "Failed to execute script", http.StatusInternalServerError)
			return
		}
	}

	// 读取 nixag/jh.txt 文件内容
	catCmd := exec.Command("cat", "nixag/jh.txt")
	catOutput, catErr := catCmd.CombinedOutput()
	if catErr != nil {
		http.Error(w, "Failed to read nixag/jh.txt", http.StatusInternalServerError)
		return
	}

	// 将文件内容编码为 Base64
	encodedOutput := base64.StdEncoding.EncodeToString(catOutput)

	// 设置响应头为纯文本
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	// 直接返回 Base64 编码的节点信息，不包含任何额外日志
	fmt.Fprintf(w, "%s", encodedOutput)
}

func alive(w http.ResponseWriter, r *http.Request) {
	log.Printf("alive")
	// 设置响应头为纯文本
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	// 直接返回 Base64 编码的节点信息，不包含任何额外日志
	fmt.Fprintf(w, "%s", "alive")
}
