// ==UserScript==
// @name         noVNC Auto Connect and Keep-Alive
// @namespace    http://tampermonkey.net/
// @version      1.9
// @description  Simulate clicks on noVNC connect button when dialog has noVNC_open class and is visible, keep session alive with Shift key events
// @author       Grok
// @match        https://*/vnc.html*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // 配置
    const CHECK_INTERVAL = 10 * 1000; // 每10秒检查并尝试点击
    const KEEP_ALIVE_INTERVAL = 30 * 1000; // 每30秒保活
    const MAX_CONNECT_ATTEMPTS = 10; // 最大连接尝试次数
    const SHIFT_KEY_CODE = 16; // Shift 键的 keyCode

    // 模拟点击事件
    function simulateClick(button) {
        if (!button) return;
        const clickEvent = new MouseEvent('click', {
            view: window,
            bubbles: true,
            cancelable: true
        });
        button.dispatchEvent(clickEvent);
        console.log('[' + new Date().toISOString() + '] Button clicked (simulated)');
    }

    // 模拟 Shift 按键（保活）
    function simulateShiftKey() {
        const canvas = document.querySelector('canvas');
        if (!canvas) {
            console.log('[' + new Date().toISOString() + '] Keep-alive: Canvas not found');
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
            console.log('[' + new Date().toISOString() + '] Keep-alive: Sent Shift key event');
        } catch (e) {
            console.error('[' + new Date().toISOString() + '] Keep-alive: Failed to send key event', e);
        }
    }

    // 自动点击按钮（仅当对话框有 noVNC_open 类且可见）
    let connectAttempts = 0;
    function checkAndClickButton() {
        if (connectAttempts >= MAX_CONNECT_ATTEMPTS) {
            console.warn('[' + new Date().toISOString() + '] Max connect attempts reached');
            return;
        }

        const dialog = document.getElementById('noVNC_connect_dlg');
        const button = document.getElementById('noVNC_connect_button');
        const dialogStyle = dialog ? window.getComputedStyle(dialog).display : 'none';
        const buttonDisabled = button ? button.disabled : true;

        console.log('[' + new Date().toISOString() + '] Dialog:', dialog);
        console.log('[' + new Date().toISOString() + '] Dialog classList:', dialog ? dialog.classList : 'N/A');
        console.log('[' + new Date().toISOString() + '] Dialog display:', dialogStyle);
        console.log('[' + new Date().toISOString() + '] Button:', button);
        console.log('[' + new Date().toISOString() + '] Button disabled:', buttonDisabled);

        if (dialog && dialog.classList.contains('noVNC_open') && dialogStyle !== 'none' && button && !buttonDisabled) {
            console.log('[' + new Date().toISOString() + '] noVNC connect dialog has noVNC_open and is visible, simulating click...');
            simulateClick(button);
            connectAttempts++;
        } else {
            console.log('[' + new Date().toISOString() + '] noVNC connect dialog missing, no noVNC_open class, not visible, or button disabled');
        }
    }

    // 保活主逻辑
    function keepAlive() {
        simulateShiftKey();
    }

    // 初始化
    console.log('[' + new Date().toISOString() + '] noVNC Auto Connect and Keep-Alive script started');
    checkAndClickButton(); // 初始点击
    setInterval(checkAndClickButton, CHECK_INTERVAL); // 定期点击
    setInterval(keepAlive, KEEP_ALIVE_INTERVAL); // 启动保活
})();
