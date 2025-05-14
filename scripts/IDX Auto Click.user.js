// ==UserScript==
// @name         IDX Auto Click
// @namespace    http://tampermonkey.net/
// @version      1.6
// @description  页面加载后延迟3秒检查复选框（id="consent"）和提交按钮（id="submit-button"），同时独立定时检查noVNC连接按钮（id="noVNC_connect_button"），各检查30秒后停止，带调试日志
// @author       Grok
// @match        *://*/vnc*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // 函数：记录调试日志
    function log(message) {
        console.log(`[AutoClickConsent] ${message}`);
    }

    // 函数：记录带时间戳的noVNC日志
    function logNoVNC(message) {
        console.log(`[${new Date().toISOString()}] ${message}`);
    }

    // 函数：查找并点击复选框
    function clickConsentCheckbox() {
        //log('正在查找复选框...');
        let checkbox = document.getElementById('consent');

        if (checkbox) {
            log('找到 ID 为 consent 的复选框，尝试点击');
            checkbox.click();
            log(`复选框点击状态: ${checkbox.checked}`);
            return true;
        } else {
            //log('未找到 ID 为 consent 的复选框，尝试通过文本定位');
            const labels = document.querySelectorAll('label');
            for (let label of labels) {
                if (label.textContent.includes('I trust the owner of this shared workspace')) {
                    log('找到包含目标文本的 label');
                    checkbox = label.querySelector('input[type="checkbox"]');
                    if (checkbox) {
                        log('找到 label 中的复选框，尝试点击');
                        checkbox.click();
                        log(`复选框点击状态: ${checkbox.checked}`);
                        return true;
                    } else {
                        log('label 中未找到复选框');
                    }
                }
            }
            //log('未找到包含目标文本的复选框');
        }
        return false;
    }

    // 函数：查找并点击提交按钮
    function clickSubmitButton() {
        log('正在查找提交按钮...');
        const button = document.getElementById('submit-button');

        if (button) {
            if (button.disabled) {
                log('提交按钮当前被禁用，尝试移除 disabled 属性');
                button.disabled = false;
            }
            log('找到 ID 为 submit-button 的按钮，尝试点击');
            button.click();
            log('提交按钮已点击');
            return true;
        } else {
            //log('未找到 ID 为 submit-button 的按钮');
            return false;
        }
    }



    // 函数：检查复选框和提交按钮
    function checkConsentAndSubmit() {
        if (clickConsentCheckbox()) {
            log('复选框点击成功，尝试点击提交按钮');
            if (clickSubmitButton()) {
                log('提交按钮点击成功，完成初始任务');
                return true;
            } else {
                //log('未找到提交按钮，继续检查');
                return false;
            }
        }
        return false;
    }

    // 函数：观察 DOM 变化
    function observeDOM() {
        log('开始观察 DOM 变化');
        const observer = new MutationObserver((mutations, obs) => {
            log('检测到 DOM 变化，重新检查元素');
            if (checkConsentAndSubmit()) {
                log('复选框和提交按钮任务完成');
            }
            if (checkAndClickNoVNCButton()) {
                log('noVNC按钮点击成功');
            }
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
        // 30秒后停止观察
        setTimeout(() => {
            log('达到最大观察时间，停止 MutationObserver');
            observer.disconnect();
        }, 30000);
    }

    // 函数：定时检查复选框和提交按钮
    function checkConsentAndSubmitPeriodically(maxDuration, interval) {
        const maxAttempts = Math.ceil(maxDuration / interval);
        let attempts = 0;
        log('启动复选框和提交按钮定时检查');
        const intervalId = setInterval(() => {
            attempts++;
            //log(`第 ${attempts} 次检查复选框和提交按钮 (共 ${maxAttempts} 次)`);
            if (checkConsentAndSubmit()) {
                log('复选框和提交按钮任务完成，停止定时检查');
                clearInterval(intervalId);
            } else if (attempts >= maxAttempts) {
                log('达到最大检查时间，停止复选框和提交按钮定时检查');
                clearInterval(intervalId);
            }
        }, interval);
    }



    // novnc
    // 函数：搜索iframe和Shadow DOM中的元素
    function queryAllElements(selector, includeShadow = false) {
        let elements = Array.from(document.querySelectorAll(selector));
        // 检查iframe
        const iframes = document.querySelectorAll('iframe');
        iframes.forEach(iframe => {
            try {
                const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                elements = elements.concat(Array.from(iframeDoc.querySelectorAll(selector)));
            } catch (e) {
                logNoVNC(`无法访问iframe内容: ${e}`);
            }
        });
        // 检查Shadow DOM
        if (includeShadow) {
            const allElements = document.getElementsByTagName('*');
            for (let el of allElements) {
                if (el.shadowRoot) {
                    elements = elements.concat(Array.from(el.shadowRoot.querySelectorAll(selector)));
                }
            }
        }
        return elements;
    }

    // 函数：检查并点击noVNC连接按钮
    function checkAndClickNoVNCButton() {
        try {
            const button = document.getElementById('noVNC_connect_button') || queryAllElements('button[id="noVNC_connect_button"]')[0];
            const dialogNoVNC = document.getElementById('noVNC_connect_dlg') || queryAllElements('div[id="noVNC_connect_dlg"]')[0];
            //logNoVNC(`DialogNoVNC: ${dialogNoVNC}`);
            //logNoVNC(`DialogNoVNC classList: ${dialogNoVNC ? dialogNoVNC.classList : 'N/A'}`);
            //logNoVNC(`Button: ${button}`);
            if (dialogNoVNC && dialogNoVNC.classList.contains('noVNC_open') && button) {
                logNoVNC('noVNC connect button found, clicking...');
                button.click();
                logNoVNC('Button clicked');
                return true;
            } else {
                //logNoVNC('noVNC connect button not found or dialogNoVNC not open');
                return false;
            }
        } catch (e) {
            logNoVNC(`检查noVNC按钮时出错: ${e}`);
            return false;
        }
    }

    // 函数：定时检查noVNC按钮
    function checkNoVNCPeriodically(maxDuration, interval) {
        const maxAttempts = 30;
        let attempts = 0;
        logNoVNC('启动noVNC按钮定时检查');
        const intervalId = setInterval(() => {
            attempts++;
            //logNoVNC(`第 ${attempts} 次检查noVNC按钮 (共 ${maxAttempts} 次)`);
            if (checkAndClickNoVNCButton()) {
                logNoVNC('noVNC按钮点击成功，停止定时检查');
                clearInterval(intervalId);
            } else if (attempts >= maxAttempts) {
                logNoVNC('达到最大检查时间，停止noVNC按钮定时检查');
                clearInterval(intervalId);
            }
        }, interval);
    }

    // novnc

    // 函数：初始化检查
    function init() {
        // 启动复选框和提交按钮检查
        log('脚本初始化，等待3秒后检查复选框和提交按钮');
        setTimeout(() => {
            log('3秒延迟结束，开始检查复选框和提交按钮');
            if (!checkConsentAndSubmit()) {
                log('初次检查未完成，开始定时检查复选框和提交按钮');
                checkConsentAndSubmitPeriodically(30000, 1000); // 检查30秒，每秒一次
            }
        }, 3000); // 3秒延迟

        // 立即启动noVNC按钮检查
        logNoVNC('立即启动noVNC按钮定时检查');
        checkNoVNCPeriodically(60000, 1000); // 检查60秒，每秒一次

        // 启动 DOM 观察
        observeDOM();
    }

    // 检查页面状态并启动
    log('脚本开始运行');
    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        log('页面已加载，直接初始化');
        init();
    } else {
        log('页面未加载，等待 DOMContentLoaded 事件');
        window.addEventListener('DOMContentLoaded', () => {
            log('DOMContentLoaded 事件触发');
            init();
        });
        // 备用：如果长时间未触发 DOMContentLoaded，强制启动
        setTimeout(() => {
            if (!window.__autoClickConsentInitialized) {
                log('DOMContentLoaded 未触发，强制初始化');
                init();
            }
        }, 5000); // 5秒后强制启动
    }
    window.__autoClickConsentInitialized = true;
})();