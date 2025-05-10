// ==UserScript==
// @name         定时刷新与noVNC自动连接器
// @namespace    http://tampermonkey.net/
// @version      2.3
// @description  按用户设置的间隔（默认3分钟）自动刷新页面，并自动点击noVNC连接按钮。页面加载时自动开始计时，状态跨页面保持。
// @author       Gemini
// @match        *://*/vnc*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_addStyle
// @run-at       document-idle
// ==/UserScript==

(function() {
    'use strict';

    // --- 配置项 ---
    const DEFAULT_INTERVAL_SECONDS = 180; // 默认刷新间隔为3分钟
    const CHECK_BUTTON_INTERVAL_SECONDS = 10; // 每10秒检查noVNC按钮
    const STORAGE_KEY_INTERVAL = 'continuousRefresherInterval'; // 存储间隔时间的键名
    const STORAGE_KEY_NEXT_RUN = 'continuousRefresherNextRun'; // 存储下一次运行时间戳的键名

    // --- 状态变量 ---
    let refreshTimerId = null;      // 存储刷新定时器的ID
    let countdownTimerId = null;    // 存储倒计时更新定时器的ID
    let buttonCheckTimerId = null;   // 存储按钮检查定时器的ID
    let isRunning = false;          // 标记当前页面脚本是否已启动计时器
    let nextRunTimestamp = 0;       // 下次运行的目标时间戳
    let panel = null;               // 存储UI面板引用

    // --- 创建用户界面 (UI) ---
    function createPanel() {
        console.log('定时刷新器: 正在创建UI面板...');
        if (document.getElementById('continuous-refresher-panel')) {
            console.log('定时刷新器: 面板已存在，跳过创建。');
            return;
        }

        panel = document.createElement('div');
        panel.id = 'continuous-refresher-panel';

        panel.innerHTML = `
            <div class="refresher-title">定时刷新与noVNC连接器</div>
            <div class="refresher-control">
                <label for="refresh-interval">间隔(秒):</label>
                <input type="number" id="refresh-interval" min="1" value="${GM_getValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS)}">
            </div>
            <div class="refresher-buttons">
                <button id="start-refresh-btn">开始</button>
                <button id="stop-refresh-btn">停止</button>
            </div>
            <div id="refresh-status">已停止</div>
        `;

        if (document.body) {
            document.body.appendChild(panel);
            console.log('定时刷新器: 面板已附加到document.body');
        } else {
            console.error('定时刷新器: document.body不可用，延迟尝试附加面板...');
            setTimeout(createPanel, 1000); // 1秒后重试
        }
    }

    // --- 检查并重新附加面板 ---
    function ensurePanel() {
        if (!document.getElementById('continuous-refresher-panel')) {
            console.log('定时刷新器: 面板丢失，重新创建...');
            createPanel();
            updateUIState();
        }
    }

    // --- 获取 UI 元素引用并更新状态 ---
    function updateUIState() {
        const intervalInput = document.getElementById('refresh-interval');
        const startButton = document.getElementById('start-refresh-btn');
        const stopButton = document.getElementById('stop-refresh-btn');
        const statusDisplay = document.getElementById('refresh-status');

        if (intervalInput && startButton && stopButton && statusDisplay) {
            startButton.disabled = isRunning;
            stopButton.disabled = !isRunning;
            intervalInput.disabled = isRunning;
            statusDisplay.textContent = isRunning ? '运行中...' : '已停止';
            console.log('定时刷新器: UI状态已更新');
        } else {
            console.error('定时刷新器: 无法获取UI元素，面板可能未正确渲染');
        }
    }

    // --- 添加 CSS 样式 ---
    GM_addStyle(`
        #continuous-refresher-panel {
            position: fixed !important;
            bottom: 15px !important;
            right: 15px !important;
            background-color: #f0f0f0 !important;
            border: 1px solid #ccc !important;
            border-radius: 5px !important;
            padding: 10px 15px !important;
            z-index: 999999 !important;
            font-family: Arial, sans-serif !important;
            font-size: 14px !important;
            box-shadow: 2px 2px 5px rgba(0,0,0,0.2) !important;
            min-width: 180px !important;
            color: #333 !important;
            opacity: 1 !important;
            pointer-events: auto !important;
        }
        #continuous-refresher-panel .refresher-title {
            font-weight: bold !important;
            margin-bottom: 8px !important;
            text-align: center !important;
            font-size: 15px !important;
        }
        #continuous-refresher-panel .refresher-control {
            margin-bottom: 8px !important;
            display: flex !important;
            align-items: center !important;
        }
        #continuous-refresher-panel label {
            margin-right: 5px !important;
            white-space: nowrap !important;
        }
        #continuous-refresher-panel input[type="number"] {
            width: 60px !important;
            padding: 3px 5px !important;
            border: 1px solid #ccc !important;
            border-radius: 3px !important;
        }
        #continuous-refresher-panel .refresher-buttons {
            display: flex !important;
            justify-content: space-around !important;
            margin-bottom: 8px !important;
        }
        #continuous-refresher-panel button {
            padding: 5px 10px !important;
            cursor: pointer !important;
            border: 1px solid #aaa !important;
            border-radius: 3px !important;
            background-color: #e0e0e0 !important;
        }
        #continuous-refresher-panel button:hover:not(:disabled) {
            background-color: #d0d0d0 !important;
        }
        #continuous-refresher-panel button:disabled {
            cursor: not-allowed !important;
            opacity: 0.6 !important;
        }
        #refresh-status {
            text-align: center !important;
            font-size: 13px !important;
            color: #555 !important;
            min-height: 1.2em !important;
        }
    `);

    // --- 功能函数 ---

    // 检查并点击noVNC连接按钮
    function checkAndClickButton() {
        try {
            const button = document.getElementById('noVNC_connect_button');
            const dialog = document.getElementById('noVNC_connect_dlg');
            console.log(`[${new Date().toISOString()}] Dialog:`, dialog);
            console.log(`[${new Date().toISOString()}] Dialog classList:`, dialog ? dialog.classList : 'N/A');
            console.log(`[${new Date().toISOString()}] Button:`, button);
            if (dialog && dialog.classList.contains('noVNC_open') && button) {
                console.log(`[${new Date().toISOString()}] noVNC connect button found, clicking...`);
                button.click();
                console.log(`[${new Date().toISOString()}] Button clicked`);
            } else {
                console.log(`[${new Date().toISOString()}] noVNC connect button not found or dialog not open`);
            }
        } catch (e) {
            console.error('定时刷新器: 检查noVNC按钮时出错:', e);
        }
    }

    // 更新倒计时显示
    function updateCountdown() {
        if (!isRunning || nextRunTimestamp <= 0) {
            if (countdownTimerId) clearInterval(countdownTimerId);
            countdownTimerId = null;
            return;
        }

        const now = Date.now();
        const remainingMs = nextRunTimestamp - now;
        const remainingSeconds = Math.max(0, Math.ceil(remainingMs / 1000));

        const statusDisplay = document.getElementById('refresh-status');
        if (statusDisplay) {
            if (remainingSeconds <= 0) {
                statusDisplay.textContent = '即将刷新...';
                if (countdownTimerId) clearInterval(countdownTimerId);
                countdownTimerId = null;
            } else {
                statusDisplay.textContent = `运行中, ${remainingSeconds} 秒后刷新`;
            }
        }
    }

    // 执行页面刷新
    function performRefresh() {
        console.log('定时刷新器: 执行刷新');
        if (refreshTimerId) clearTimeout(refreshTimerId);
        if (countdownTimerId) clearInterval(countdownTimerId);
        refreshTimerId = null;
        countdownTimerId = null;
        isRunning = false;

        const nextRunCheck = GM_getValue(STORAGE_KEY_NEXT_RUN, 0);
        if (nextRunCheck > 0) {
            const intervalSeconds = parseInt(GM_getValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS), 10);
            const nextTimestamp = Date.now() + intervalSeconds * 1000;
            GM_setValue(STORAGE_KEY_NEXT_RUN, nextTimestamp);
            console.log(`定时刷新器: 下次刷新时间戳已设置: ${new Date(nextTimestamp).toLocaleTimeString()}`);
        } else {
            console.log('定时刷新器: 检测到已停止，刷新后不再继续。');
        }

        const statusDisplay = document.getElementById('refresh-status');
        if (statusDisplay) {
            statusDisplay.textContent = '正在刷新页面...';
        }
        setTimeout(() => {
            window.location.reload();
        }, 50);
    }

    // 启动或恢复刷新流程
    function startRefresh(isAutoStart = false) {
        let intervalValue;
        let delayMs;

        try {
            if (isAutoStart) {
                intervalValue = parseInt(GM_getValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS), 10);
                nextRunTimestamp = GM_getValue(STORAGE_KEY_NEXT_RUN, 0);
                const now = Date.now();

                if (nextRunTimestamp <= 0) {
                    nextRunTimestamp = now + intervalValue * 1000;
                    GM_setValue(STORAGE_KEY_NEXT_RUN, nextRunTimestamp);
                    console.log(`定时刷新器: 自动启动 - 无有效下次运行时间，重新设置: ${new Date(nextRunTimestamp).toLocaleTimeString()}`);
                }

                delayMs = Math.max(0, nextRunTimestamp - now);
                console.log(`定时刷新器: 自动启动 - 计划时间: ${new Date(nextRunTimestamp).toLocaleTimeString()}, 剩余: ${delayMs}ms`);

                if (delayMs < 100) {
                    console.log('定时刷新器: 自动启动 - 时间已到，立即刷新。');
                    performRefresh();
                    return;
                }
            } else {
                const intervalInput = document.getElementById('refresh-interval');
                intervalValue = parseInt(intervalInput.value, 10);
                if (isNaN(intervalValue) || intervalValue < 1) {
                    alert('请输入有效的刷新间隔（必须是大于等于 1 的整数）。');
                    intervalInput.value = GM_getValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS);
                    return;
                }
                GM_setValue(STORAGE_KEY_INTERVAL, intervalValue);

                delayMs = intervalValue * 1000;
                nextRunTimestamp = Date.now() + delayMs;
                GM_setValue(STORAGE_KEY_NEXT_RUN, nextRunTimestamp);
                console.log(`定时刷新器: 手动启动 - 间隔: ${intervalValue}s, 下次运行: ${new Date(nextRunTimestamp).toLocaleTimeString()}`);
            }

            if (refreshTimerId) clearTimeout(refreshTimerId);
            if (countdownTimerId) clearInterval(countdownTimerId);
            if (buttonCheckTimerId) clearInterval(buttonCheckTimerId);

            isRunning = true;

            refreshTimerId = setTimeout(performRefresh, delayMs);
            updateCountdown();
            countdownTimerId = setInterval(updateCountdown, 1000);
            buttonCheckTimerId = setInterval(checkAndClickButton, CHECK_BUTTON_INTERVAL_SECONDS * 1000);
            console.log('noVNC Auto Connect: 定期检查已启动');

            updateUIState();
        } catch (e) {
            console.error('定时刷新器: 启动刷新流程时出错:', e);
        }
    }

    // 停止刷新流程
    function stopRefresh(isInternalCall = false) {
        try {
            if (refreshTimerId) clearTimeout(refreshTimerId);
            if (countdownTimerId) clearInterval(countdownTimerId);
            if (buttonCheckTimerId) clearInterval(buttonCheckTimerId);

            refreshTimerId = null;
            countdownTimerId = null;
            buttonCheckTimerId = null;

            GM_setValue(STORAGE_KEY_NEXT_RUN, 0);

            isRunning = false;
            nextRunTimestamp = 0;

            updateUIState();

            if (!isInternalCall) {
                console.log('定时刷新器: 已手动停止');
                console.log('noVNC Auto Connect: 定期检查已停止');
            }
        } catch (e) {
            console.error('定时刷新器: 停止刷新流程时出错:', e);
        }
    }

    // --- 事件监听器 ---
    function setupEventListeners() {
        const startButton = document.getElementById('start-refresh-btn');
        const stopButton = document.getElementById('stop-refresh-btn');

        if (startButton && stopButton) {
            startButton.addEventListener('click', () => startRefresh(false));
            stopButton.addEventListener('click', () => stopRefresh(false));
            console.log('定时刷新器: 事件监听器已设置');
        } else {
            console.error('定时刷新器: 无法设置事件监听器，按钮未找到');
        }
    }

    // --- 初始化和自动启动 ---
    function initialize() {
        console.log('定时刷新器与noVNC脚本: 初始化...');
        try {
            createPanel();
            setupEventListeners();
            checkAndClickButton(); // 初始检查noVNC按钮
            setInterval(ensurePanel, 5000); // 每5秒检查面板是否存在
            console.log('定时刷新器: 页面加载，自动开始计时...');
            startRefresh(true);
        } catch (e) {
            console.error('定时刷新器: 初始化时出错:', e);
        }
    }

    initialize();
})();
