// ==UserScript==
// @name         noVNC Auto Connect
// @namespace    http://tampermonkey.net/
// @version      1.3
// @description  自动检测并点击 noVNC 连接按钮
// @author       Grok
// @match        https://*/vnc.html*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    const CHECK_INTERVAL = 10000; // 每10秒检查一次

    function checkAndClickButton() {
        const button = document.getElementById('noVNC_connect_button');
        const dialog = document.getElementById('noVNC_connect_dlg');
        console.log('[' + new Date().toISOString() + '] Dialog:', dialog);
        console.log('[' + new Date().toISOString() + '] Dialog classList:', dialog ? dialog.classList : 'N/A');
        console.log('[' + new Date().toISOString() + '] Button:', button);
        if (dialog && dialog.classList.contains('noVNC_open') && button) {
            console.log('[' + new Date().toISOString() + '] noVNC connect button found, clicking...');
            button.click();
            console.log('[' + new Date().toISOString() + '] Button clicked');
        } else {
            console.log('[' + new Date().toISOString() + '] noVNC connect button not found or dialog not open');
        }
    }

    // 初始检查
    console.log('[' + new Date().toISOString() + '] noVNC Auto Connect script started');
    checkAndClickButton();

    // 定期检查
    setInterval(checkAndClickButton, CHECK_INTERVAL);

    // 监听 DOM 变化
    //const observer = new MutationObserver(checkAndClickButton);
    //observer.observe(document.body, { childList: true, subtree: true });
})();