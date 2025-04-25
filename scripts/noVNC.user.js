// ==UserScript==
// @name         集成 VNC 自动刷新与 noVNC 自动连接（带窗口隐藏与延迟）
// @namespace    http://tampermonkey.net/
// @version      2.5
// @description  在 vnc.html 页面上集成持续页面刷新与 noVNC 自动连接和保活功能。首次刷新使用3分钟间隔，后续使用存储的间隔值。页面加载时自动开始刷新，自动点击 noVNC 连接按钮，并发送 Shift 键事件保持会话活跃。刷新器窗口支持自动隐藏和显示，隐藏后有延迟防止立即触发显示。
// @author       Gemini & Grok
// @match        https://*/vnc.html*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_addStyle
// @run-at       document-idle
// ==/UserScript==

(function() {
    'use strict';

    // --- 配置项 ---
    const DEFAULT_INTERVAL_SECONDS = 180; // 默认刷新间隔（3分钟，首次使用）
    const STORAGE_KEY_INTERVAL = 'continuousRefresherInterval'; // 刷新间隔存储键
    const STORAGE_KEY_NEXT_RUN = 'continuousRefresherNextRun'; // 下次刷新时间戳存储键
    const STORAGE_KEY_VISIBILITY = 'continuousRefresherVisibility'; // 窗口可见性存储键
    const CHECK_INTERVAL = 10; // noVNC 按钮检查间隔（秒）
    const KEEP_ALIVE_INTERVAL = 30; // noVNC 保活间隔（秒）
    const MAX_CONNECT_ATTEMPTS = 10; // noVNC 最大连接尝试次数
    const SHIFT_KEY_CODE = 16; // Shift 键代码
    const TICK_INTERVAL = 1000; // 共享定时器间隔（1秒）
    const AUTO_HIDE_DELAY = 5000; // 自动隐藏延时（5秒）
    const HIDDEN_AREA_SIZE = 100; // 隐藏区域大小（像素，100x100）
    const HIDE_DEBOUNCE_DELAY = 1000; // 隐藏后显示延迟（1秒）

    // --- 状态变量 ---
    let refreshTimerId = null; // 即时刷新定时器
    let countdownTimerId = null; // 共享定时器
    let autoHideTimerId = null; // 自动隐藏定时器
    let isRunning = false; // 刷新器运行状态
    let nextRunTimestamp = 0; // 下次刷新时间戳
    let connectAttempts = 0; // noVNC 连接尝试次数
    let secondsSinceStart = 0; // noVNC 任务计数器
    let isPanelVisible = true; // 窗口当前可见性
    let lastHideTimestamp = 0; // 最后一次隐藏时间戳

    // --- 创建 UI（刷新器） ---
    const panel = document.createElement('div');
    panel.id = 'continuous-refresher-panel';
    panel.innerHTML = `
        <div class="refresher-title">持续定时刷新器</div>
        <div class="refresher-control">
            <label for="refresh-interval">间隔(秒):</label>
            <input type="number" id="refresh-interval" min="1" value="${GM_getValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS)}">
        </div>
        <div class="refresher-buttons">
            <button id="start-refresh-btn">开始刷新</button>
            <button id="stop-refresh-btn">停止刷新</button>
            <button id="toggle-visibility-btn">隐藏</button>
        </div>
        <div id="refresh-status">已停止</div>
    `;
    document.body.appendChild(panel);

    // --- 创建隐藏区域（用于鼠标检测） ---
    const hiddenArea = document.createElement('div');
    hiddenArea.id = 'continuous-refresher-hidden-area';
    document.body.appendChild(hiddenArea);

    // --- 获取 UI 元素 ---
    const intervalInput = document.getElementById('refresh-interval');
    const startButton = document.getElementById('start-refresh-btn');
    const stopButton = document.getElementById('stop-refresh-btn');
    const toggleButton = document.getElementById('toggle-visibility-btn');
    const statusDisplay = document.getElementById('refresh-status');

    // --- 添加 CSS 样式 ---
    GM_addStyle(`
        #continuous-refresher-panel {
            position: fixed;
            bottom: 15px;
            right: 15px;
            background-color: #f0f0f0;
            border: 1px solid #ccc;
            border-radius: 5px;
            padding: 10px 15px;
            z-index: 9999;
            font-family: Arial, sans-serif;
            font-size: 14px;
            box-shadow: 2px 2px 5px rgba(0,0,0,0.2);
            min-width: 180px;
            color: #333;
        }
        #continuous-refresher-hidden-area {
            position: fixed;
            bottom: 0;
            right: 0;
            width: ${HIDDEN_AREA_SIZE}px;
            height: ${HIDDEN_AREA_SIZE}px;
            z-index: 9998;
            display: none;
        }
        #continuous-refresher-panel .refresher-title {
            font-weight: bold;
            margin-bottom: 8px;
            text-align: center;
            font-size: 15px;
        }
        #continuous-refresher-panel .refresher-control {
            margin-bottom: 8px;
            display: flex;
            align-items: center;
        }
        #continuous-refresher-panel label {
            margin-right: 5px;
            white-space: nowrap;
        }
        #continuous-refresher-panel input[type="number"] {
            width: 60px;
            padding: 3px 5px;
            border: 1px solid #ccc;
            border-radius: 3px;
        }
        #continuous-refresher-panel .refresher-buttons {
            display: flex;
            justify-content: space-around;
            margin-bottom: 8px;
        }
        #continuous-refresher-panel button {
            padding: 5px 10px;
            cursor: pointer;
            border: 1px solid #aaa;
            border-radius: 3px;
            background-color: #e0e0e0;
        }
        #continuous-refresher-panel button:hover:not(:disabled) {
            background-color: #d0d0d0;
        }
        #continuous-refresher-panel button:disabled {
            cursor: not-allowed;
            opacity: 0.6;
        }
        #refresh-status {
            text-align: center;
            font-size: 13px;
            color: #555;
            min-height: 1.2em;
        }
    `);

    // --- 窗口显示/隐藏函数 ---
    function updatePanelVisibility(visible) {
        isPanelVisible = visible;
        GM_setValue(STORAGE_KEY_VISIBILITY, visible ? 'visible' : 'hidden');
        panel.style.display = visible ? 'block' : 'none';
        hiddenArea.style.display = visible ? 'none' : 'block';
        toggleButton.textContent = visible ? '隐藏' : '显示';
        if (!visible) {
            lastHideTimestamp = Date.now();
        }
        console.log(`Refresher: 窗口${visible ? '显示' : '隐藏'}`);
        if (visible && autoHideTimerId) {
            clearTimeout(autoHideTimerId);
            autoHideTimerId = setTimeout(() => {
                if (isPanelVisible) updatePanelVisibility(false);
            }, AUTO_HIDE_DELAY);
        }
    }

    // --- 共享定时器逻辑 ---
    function tick() {
        secondsSinceStart++;
        updateCountdown(); // 更新刷新器 UI
        checkAndClickButton(); // 检查 noVNC 按钮（每10秒）
        keepAlive(); // 发送 Shift 键（每30秒）
    }

    // --- 刷新器函数 ---
    function updateCountdown() {
        if (!isRunning || nextRunTimestamp <= 0) {
            statusDisplay.textContent = '已停止';
            return;
        }
        const now = Date.now();
        const remainingMs = nextRunTimestamp - now;
        const remainingSeconds = Math.max(0, Math.ceil(remainingMs / 1000));
        if (remainingSeconds <= 0) {
            statusDisplay.textContent = '即将刷新...';
            performRefresh();
        } else {
            statusDisplay.textContent = `运行中, ${remainingSeconds} 秒后刷新`;
        }
    }

    function performRefresh() {
        console.log('Refresher: 执行刷新');
        if (refreshTimerId) clearTimeout(refreshTimerId);
        refreshTimerId = null;
        isRunning = false;
        const nextRunCheck = GM_getValue(STORAGE_KEY_NEXT_RUN, 0);
        if (nextRunCheck > 0) {
            const intervalSeconds = parseInt(GM_getValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS), 10);
            const nextTimestamp = Date.now() + intervalSeconds * 1000;
            GM_setValue(STORAGE_KEY_NEXT_RUN, nextTimestamp);
            console.log(`Refresher: 下次刷新时间: ${new Date(nextTimestamp).toLocaleTimeString()}, 间隔: ${intervalSeconds}s`);
        } else {
            console.log('Refresher: 已停止，不继续刷新。');
        }
        statusDisplay.textContent = '正在刷新页面...';
        setTimeout(() => window.location.reload(), 50);
    }

    function startRefresh(isAutoStart = false) {
        let intervalValue;
        let delayMs;
        if (isAutoStart) {
            intervalValue = parseInt(GM_getValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS), 10);
            nextRunTimestamp = GM_getValue(STORAGE_KEY_NEXT_RUN, 0);
{asin:1}            const now = Date.now();
            if (nextRunTimestamp <= 0) {
                console.log('Refresher: 自动启动 - 无下次运行时间，设置为新任务。');
                intervalValue = parseInt(GM_getValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS), 10);
                delayMs = intervalValue * 1000;
                nextRunTimestamp = now + delayMs;
                GM_setValue(STORAGE_KEY_NEXT_RUN, nextRunTimestamp);
            } else {
                delayMs = Math.max(0, nextRunTimestamp - now);
                console.log(`Refresher: 自动启动 - 计划时间: ${new Date(nextRunTimestamp).toLocaleTimeString()}, 剩余: ${delayMs}ms, 间隔: ${intervalValue}s`);
                if (delayMs < 100) {
                    console.log('Refresher: 自动启动 - 时间已到，立即刷新。');
                    performRefresh();
                    return;
                }
            }
        } else {
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
            console.log(`Refresher: 手动启动 - 间隔: ${intervalValue}s, 下次运行: ${new Date(nextRunTimestamp).toLocaleTimeString()}`);
        }
        if (refreshTimerId) clearTimeout(refreshTimerId);
        isRunning = true;
        startButton.disabled = true;
        stopButton.disabled = false;
        intervalInput.disabled = true;
        if (delayMs < TICK_INTERVAL) {
            refreshTimerId = setTimeout(performRefresh, delayMs);
        }
        // 设置自动隐藏
        if (isPanelVisible && !autoHideTimerId) {
            autoHideTimerId = setTimeout(() => {
                if (isPanelVisible) updatePanelVisibility(false);
            }, AUTO_HIDE_DELAY);
        }
    }

    function stopRefresh(isInternalCall = false) {
        if (refreshTimerId) clearTimeout(refreshTimerId);
        if (autoHideTimerId) clearTimeout(autoHideTimerId);
        refreshTimerId = null;
        autoHideTimerId = null;
        GM_setValue(STORAGE_KEY_NEXT_RUN, 0);
        isRunning = false;
        nextRunTimestamp = 0;
        statusDisplay.textContent = '已停止';
        startButton.disabled = false;
        stopButton.disabled = true;
        intervalInput.disabled = false;
        if (!isInternalCall) {
            console.log('Refresher: 手动停止');
        }
    }

    // --- noVNC 函数 ---
    function simulateClick(button) {
        if (!button) return;
        const clickEvent = new MouseEvent('click', {
            view: window,
            bubbles: true,
            cancelable: true
        });
        button.dispatchEvent(clickEvent);
        console.log('[' + new Date().toISOString() + '] noVNC: 按钮点击（模拟）');
    }

    function simulateShiftKey() {
        const canvas = document.querySelector('canvas');
        if (!canvas) {
            console.log('[' + new Date().toISOString() + '] noVNC: 保活 - 未找到画布');
            return;
        }
        try {
            const keyDownEvent = new KeyboardEvent('keydown', {
                keyCode: SHIFT_KEY_CODE,
                bubbles: true,
                cancelable: true
            });
            const keyUpEvent = new KeyboardEvent('keyup', {
                keyCode: SHIFT_KEY_CODE,
                bubbles: true,
                cancelable: true
            });
            canvas.dispatchEvent(keyDownEvent);
            canvas.dispatchEvent(keyUpEvent);
            console.log('[' + new Date().toISOString() + '] noVNC: 保活 - 已发送 Shift 键事件');
        } catch (e) {
            console.error('[' + new Date().toISOString() + '] noVNC: 保活 - 发送键事件失败', e);
        }
    }

    function checkAndClickButton() {
        if (secondsSinceStart % CHECK_INTERVAL !== 0) return; // 每10秒运行
        if (connectAttempts >= MAX_CONNECT_ATTEMPTS) {
            console.warn('[' + new Date().toISOString() + '] noVNC: 达到最大连接尝试次数');
            return;
        }
        const dialog = document.getElementById('noVNC_connect_dlg');
        const button = document.getElementById('noVNC_connect_button');
        const dialogStyle = dialog ? window.getComputedStyle(dialog).display : 'none';
        const buttonDisabled = button ? button.disabled : true;
        console.log('[' + new Date().toISOString() + '] noVNC: 对话框:', dialog);
        console.log('[' + new Date().toISOString() + '] noVNC: 对话框类列表:', dialog ? dialog.classList : 'N/A');
        console.log('[' + new Date().toISOString() + '] noVNC: 对话框显示:', dialogStyle);
        console.log('[' + new Date().toISOString() + '] noVNC: 按钮:', button);
        console.log('[' + new Date().toISOString() + '] noVNC: 按钮禁用:', buttonDisabled);
        if (dialog && dialog.classList.contains('noVNC_open') && dialogStyle !== 'none' && button && !buttonDisabled) {
            console.log('[' + new Date().toISOString() + '] noVNC: 连接对话框有 noVNC_open 类且可见，模拟点击...');
            simulateClick(button);
            connectAttempts++;
        } else {
            console.log('[' + new Date().toISOString() + '] noVNC: 连接对话框缺失、无 noVNC_open 类、不可见或按钮禁用');
        }
    }

    function keepAlive() {
        if (secondsSinceStart % KEEP_ALIVE_INTERVAL !== 0) return; // 每30秒运行
        simulateShiftKey();
    }

    // --- 事件监听器 ---
    startButton.addEventListener('click', () => startRefresh(false));
    stopButton.addEventListener('click', () => stopRefresh(false));
    toggleButton.addEventListener('click', () => updatePanelVisibility(!isPanelVisible));

    // 鼠标进入面板时取消自动隐藏
    panel.addEventListener('mouseenter', () => {
        if (autoHideTimerId) {
            clearTimeout(autoHideTimerId);
            autoHideTimerId = null;
        }
    });

    // 鼠标离开面板时重新设置自动隐藏
    panel.addEventListener('mouseleave', () => {
        if (isPanelVisible && !autoHideTimerId) {
            autoHideTimerId = setTimeout(() => {
                if (isPanelVisible) updatePanelVisibility(false);
            }, AUTO_HIDE_DELAY);
        }
    });

    // 鼠标移动检测隐藏区域
    document.addEventListener('mousemove', (event) => {
        if (isPanelVisible) return;
        const now = Date.now();
        if (now - lastHideTimestamp < HIDE_DEBOUNCE_DELAY) {
            console.log('Refresher: 忽略显示请求，仍在隐藏延迟期间');
            return;
        }
        const x = event.clientX;
        const y = event.clientY;
        const windowWidth = window.innerWidth;
        const windowHeight = window.innerHeight;
        if (x > windowWidth - HIDDEN_AREA_SIZE && y > windowHeight - HIDDEN_AREA_SIZE) {
            updatePanelVisibility(true);
        }
    });

    // --- 初始化 ---
    function initialize() {
        console.log('集成 VNC 脚本: 初始化于', window.location.href);
        // 初始化刷新间隔
        const storedInterval = GM_getValue(STORAGE_KEY_INTERVAL);
        if (storedInterval === undefined) {
            console.log(`Refresher: 首次运行，设置默认间隔: ${DEFAULT_INTERVAL_SECONDS}s`);
            GM_setValue(STORAGE_KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS);
            intervalInput.value = DEFAULT_INTERVAL_SECONDS;
        } else {
            console.log(`Refresher: 使用存储的间隔: ${storedInterval}s`);
            intervalInput.value = storedInterval;
        }
        // 初始化窗口可见性
        const storedVisibility = GM_getValue(STORAGE_KEY_VISIBILITY, 'visible');
        isPanelVisible = storedVisibility === 'visible';
        updatePanelVisibility(isPanelVisible);
        // 初始化 noVNC
        console.log('[' + new Date().toISOString() + '] noVNC: 自动连接与保活已启动');
        checkAndClickButton(); // 初始按钮检查
        // 初始化刷新器
        nextRunTimestamp = GM_getValue(STORAGE_KEY_NEXT_RUN, 0);
        const now = Date.now();
        if (nextRunTimestamp > 0 && now < nextRunTimestamp + 1000) {
            console.log('Refresher: 检测到未完成的刷新任务，自动恢复...');
            startRefresh(true);
        } else {
            console.log('Refresher: 无未完成任务，自动启动新刷新任务...');
            startRefresh(false); // 每次加载自动启动
        }
        // 启动共享定时器
        countdownTimerId = setInterval(tick, TICK_INTERVAL);
    }

    initialize();
})();
