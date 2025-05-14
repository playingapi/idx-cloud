// ==UserScript==
// @name         Tailscale Admin Machines Dynamic Links
// @namespace    http://tampermonkey.net/
// @version      1.20
// @description  Dynamically adds hyperlinks for disconnected and connected idx devices on Tailscale admin machines page without modifying existing DOM structure, with a toggle switch to auto-open links for offline devices with 1-minute delay, pending open indicator, opened indicator, ensuring connected links are always visible, hiding original Connected text and time elements, adding status indicator spans for online (green) and offline (gray) states, aligning content to top with coordinated styling, and supporting dynamically added idx devices
// @author       Grok
// @match        https://login.tailscale.com/admin/*
// @grant        GM_getValue
// @grant        GM_setValue
// ==/UserScript==

(function() {
    'use strict';

    // Predefined URL mappings for disconnected devices
    const urlMappings = {
        'go': 'https://idx.google.com/go-50795874',
        'zz': 'https://idx.google.com/zz-46638115',
        'as59': 'https://idx.google.com/as59-72660828',
        'as': 'https://idx.google.com/as-06258770',
        'bb2': 'https://idx.google.com/bb2-42609298',
        'mm3': 'https://idx.google.com/mm3-71395385',
        'mm4': 'https://idx.google.com/mm4-72427397',
        'yy': 'https://idx.google.com/yy-07576362',
        'pc5': 'https://idx.google.com/pc5-58398084',
        'pc2': 'https://idx.google.com/pc2-96638532',
        'mac': 'https://idx.google.com/mac-63587035',
        'mm2': 'https://idx.google.com/mm2-07431120',
        'pc3': 'https://idx.google.com/pc3-42902620',
        'pc': 'https://idx.google.com/pc-21799598',
        'pc4': 'https://idx.google.com/pc4-14661919',
        'as58': 'https://idx.google.com/as58-99020469',
        'as57': 'https://idx.google.com/as57-30623104',
        'as56': 'https://idx.google.com/as56-88207237',
        'as55': 'https://idx.google.com/as55-64938699',
        'as54': 'https://idx.google.com/as54-10589463',
        'as53': 'https://idx.google.com/as53-08960215',
        'as52': 'https://idx.google.com/as52-36572775',
        'as51': 'https://idx.google.com/as51-76391025',
        'as50': 'https://idx.google.com/as50-27215668',
        'as49': 'https://idx.google.com/as49-04921587',
        'as48': 'https://idx.google.com/as48-40641847',
        'as47': 'https://idx.google.com/as47-46616061',
        'as46': 'https://idx.google.com/as46-21637575',
        'as45': 'https://idx.google.com/as45-35926550',
        'as44': 'https://idx.google.com/as44-33304738',
        'as43': 'https://idx.google.com/as43-77674803',
        'as42': 'https://idx.google.com/as42-08968836',
        'as41': 'https://idx.google.com/as41-98300373',
        'as40': 'https://idx.google.com/as40-11369312',
        'as39': 'https://idx.google.com/as39-44375909',
        'as38': 'https://idx.google.com/as38-83313368',
        'as37': 'https://idx.google.com/as37-32572465',
        'as36': 'https://idx.google.com/as36-21313701',
        'as35': 'https://idx.google.com/as35-68446422',
        'as34': 'https://idx.google.com/as34-29906130',
        'as33': 'https://idx.google.com/as33-46449899',
        'as32': 'https://idx.google.com/as32-49939541',
        'as31': 'https://idx.google.com/as31-66878196',
        'as30': 'https://idx.google.com/as30-55824354',
        'as29': 'https://idx.google.com/as29-51920829',
        'as28': 'https://idx.google.com/as28-13719532',
        'as27': 'https://idx.google.com/as27-75952991',
        'as26': 'https://idx.google.com/as26-67773044',
        'as25': 'https://idx.google.com/as25-31035038',
        'as24': 'https://idx.google.com/as24-25032512',
        'as23': 'https://idx.google.com/as23-14059436',
        'as22': 'https://idx.google.com/as22-76743936',
        'as21': 'https://idx.google.com/as21-27596304',
        'as20': 'https://idx.google.com/as20-21705651',
        'as19': 'https://idx.google.com/as19-46914200',
        'as18': 'https://idx.google.com/as18-50638533',
        'as17': 'https://idx.google.com/as17-77920929',
        'as16': 'https://idx.google.com/as16-45144002',
        'as15': 'https://idx.google.com/as15-46514411',
        'as14': 'https://idx.google.com/as14-05276288',
        'as13': 'https://idx.google.com/as13-36883470',
        'as12': 'https://idx.google.com/as12-57094464',
        'as11': 'https://idx.google.com/as11-62555896',
        'as10': 'https://idx.google.com/as10-68879729',
        'as9': 'https://idx.google.com/as9-54924723',
        'as8': 'https://idx.google.com/as8-80844763',
        'as7': 'https://idx.google.com/as7-47093553',
        'as6': 'https://idx.google.com/as6-97872694',
        'as5': 'https://idx.google.com/as5-81190417',
        'as4': 'https://idx.google.com/as4-48571374',
        'as3': 'https://idx.google.com/as3-02722524',
        'as2': 'https://idx.google.com/as2-52572253',
        'mm': 'https://idx.google.com/mm-56884358'
    };

    // Track devices that have been auto-opened
    const autoOpenedDevices = new Set();
    // Track timeouts for delayed auto-open
    const autoOpenTimeouts = new Map();

    // Toggle switch state
    let autoOpenEnabled = GM_getValue('autoOpenEnabled', false);

    // Function to create and inject UI toggle button
    function injectToggleButton() {
        const container = document.createElement('div');
        container.style.position = 'fixed';
        container.style.top = '10px';
        container.style.right = '10px';
        container.style.zIndex = '1000';
        container.style.background = '#000';
        container.style.padding = '10px';
        container.style.border = '1px solid #ccc';
        container.style.borderRadius = '5px';

        const label = document.createElement('label');
        label.textContent = '自动打开离线设备链接: ';
        label.style.marginRight = '5px';

        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.checked = autoOpenEnabled;
        checkbox.addEventListener('change', () => {
            autoOpenEnabled = checkbox.checked;
            GM_setValue('autoOpenEnabled', autoOpenEnabled);
            console.log('Auto-open toggled:', autoOpenEnabled);
            if (autoOpenEnabled) {
                autoOpenedDevices.clear(); // Reset on toggle
                autoOpenTimeouts.forEach((timeoutId, machineName) => {
                    clearTimeout(timeoutId);
                    console.log('Cleared auto-open timeout for:', machineName);
                });
                autoOpenTimeouts.clear();
                processRows(); // Reprocess rows immediately
            } else {
                // Clear all pending timeouts and indicators when disabling
                autoOpenTimeouts.forEach((timeoutId, machineName) => {
                    clearTimeout(timeoutId);
                    console.log('Cleared auto-open timeout for:', machineName);
                });
                autoOpenTimeouts.clear();
                // Remove all pending and opened indicators
                document.querySelectorAll('span[data-pending-open="true"], span[data-opened="true"]').forEach(span => {
                    span.remove();
                    console.log('Removed indicator (pending or opened) for:', span.dataset.machineName || 'unknown');
                });
            }
        });

        container.appendChild(label);
        container.appendChild(checkbox);
        document.body.appendChild(container);
        console.log('Toggle button injected');
    }

    // Debounce function to limit processRows execution
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    // Function to process table rows
    function processRows() {
        console.log('Processing rows');
        const rows = document.querySelectorAll('tbody tr');
        console.log('Found rows:', rows.length);

        rows.forEach(row => {
            const statusCell = row.querySelector('td.hidden.lg\\:block.md\\:flex-auto');
            if (!statusCell) {
                console.log('Status cell not found in row');
                return;
            }

            const link = row.querySelector('td a.stretched-link');
            if (!link) {
                console.log('Link not found in row');
                return;
            }
            const machineName = link.textContent.trim();
            console.log('Machine name:', machineName);

            const isIdxDevice = machineName.startsWith('idx-');
            if (!isIdxDevice) {
                console.log('Not an idx device:', machineName);
                return;
            }
            console.log('Detected idx device:', machineName);

            // Remove all existing processed links, indicators, and status indicators in statusCell
            const existingLinks = statusCell.querySelectorAll('a[data-processed="true"]');
            existingLinks.forEach(link => {
                link.remove();
                console.log('Removed existing processed link for:', machineName);
            });
            const existingIndicators = statusCell.querySelectorAll('span[data-pending-open="true"], span[data-opened="true"]');
            existingIndicators.forEach(indicator => {
                indicator.remove();
                console.log('Removed existing indicator (pending or opened) for:', machineName);
            });
            const existingStatusIndicators = statusCell.querySelectorAll('span[data-status-indicator="true"]');
            existingStatusIndicators.forEach(indicator => {
                indicator.remove();
                console.log('Removed existing status indicator for:', machineName);
            });

            // Set flex display for statusCell to align content to top with padding
            statusCell.style.display = 'flex';
            statusCell.style.alignItems = 'flex-start';
            statusCell.style.gap = '5px';
            statusCell.style.paddingTop = '2px';
            console.log('Set statusCell styles for:', machineName, {
                display: 'flex',
                alignItems: 'flex-start',
                gap: '5px',
                paddingTop: '2px'
            });

            // Handle disconnected devices
            const statusSpan = statusCell.querySelector('span[data-state="closed"]');
            if (statusSpan) {
                const match = machineName.match(/idx-([a-z0-9]+)-\d+/);
                if (match && match[1]) {
                    const identifier = match[1];
                    console.log('Extracted identifier:', identifier);

                    const url = urlMappings[identifier];
                    if (url) {
                        console.log('Found URL:', url);
                        const timeElement = statusCell.querySelector('time');
                        if (timeElement) {
                            // Hide original time element
                            timeElement.style.display = 'none';
                            console.log('Hid original time element for:', machineName);

                            // Save original time text
                            const originalTimeText = timeElement.textContent;
                            console.log('Saved original time text for:', machineName, originalTimeText);

                            // Insert status indicator (gray dot for offline)
                            const statusIndicator = document.createElement('span');
                            statusIndicator.className = 'inline-block w-2 h-2 rounded-full bg-gray-500 mr-2';
                            statusIndicator.dataset.statusIndicator = 'true';
                            statusIndicator.style.marginTop = '15px';
                            statusCell.appendChild(statusIndicator);
                            console.log('Inserted status indicator (gray) for:', machineName);

                            const timeText = originalTimeText;
                            const indicator = timeElement.querySelector('span.inline-block.w-2.h-2.rounded-full');
                            const linkElement = document.createElement('a');
                            linkElement.href = url;
                            linkElement.textContent = timeText.replace(indicator ? indicator.textContent : '', '').trim();
                            linkElement.target = '_blank';
                            linkElement.dataset.processed = 'true';
                            const computedStyle = window.getComputedStyle(timeElement);
                            linkElement.style.color = computedStyle.color; // Match text-sm color
                            linkElement.style.fontSize = computedStyle.fontSize;
                            linkElement.style.fontFamily = computedStyle.fontFamily;
                            linkElement.style.fontWeight = computedStyle.fontWeight;
                            linkElement.style.lineHeight = computedStyle.lineHeight;
                            linkElement.style.textDecoration = 'underline';
                            linkElement.style.display = 'inline !important';
                            linkElement.style.opacity = '1';
                            linkElement.style.visibility = 'visible';
                            linkElement.style.pointerEvents = 'auto';
                            linkElement.style.zIndex = '1';
                            linkElement.style.position = 'relative';
                            linkElement.style.whiteSpace = 'nowrap';
                            linkElement.style.marginTop = '7px';
                            linkElement.style.marginLeft = '-5px';

                            // Insert link into statusCell
                            statusCell.appendChild(linkElement);
                            console.log('Inserted link for disconnected device:', identifier);
                            console.log('Link styles:', {
                                display: window.getComputedStyle(linkElement).display,
                                opacity: window.getComputedStyle(linkElement).opacity,
                                visibility: window.getComputedStyle(linkElement).visibility,
                                color: window.getComputedStyle(linkElement).color,
                                fontSize: window.getComputedStyle(linkElement).fontSize
                            });
                            console.log('Status cell HTML:', statusCell.outerHTML);

                            // Auto-open logic with 1-minute delay
                            if (autoOpenEnabled && !autoOpenedDevices.has(machineName)) {
                                console.log('Scheduling auto-open for:', machineName, 'in 60 seconds');
                                const pendingIndicator = document.createElement('span');
                                pendingIndicator.textContent = '待打开';
                                pendingIndicator.dataset.pendingOpen = 'true';
                                pendingIndicator.dataset.machineName = machineName;
                                pendingIndicator.style.color = '#ffffff';
                                pendingIndicator.style.backgroundColor = '#f28c38';
                                pendingIndicator.style.opacity = '0.9';
                                pendingIndicator.style.padding = '1px 4px';
                                pendingIndicator.style.borderRadius = '3px';
                                pendingIndicator.style.marginLeft = '4px';
                                pendingIndicator.style.fontSize = computedStyle.fontSize;
                                pendingIndicator.style.lineHeight = computedStyle.lineHeight;
                                pendingIndicator.style.display = 'inline !important';
                                pendingIndicator.style.visibility = 'visible';
                                openedIndicator.style.marginTop = '7px';
                                statusCell.appendChild(pendingIndicator);
                                console.log('Inserted pending open indicator for:', machineName);

                                const timeoutId = setTimeout(() => {
                                    if (autoOpenEnabled && !autoOpenedDevices.has(machineName)) {
                                        console.log('Auto-opening link for:', machineName);
                                        window.open(url, '_blank');
                                        autoOpenedDevices.add(machineName);

                                        // Remove pending indicator
                                        if (pendingIndicator.parentNode) {
                                            pendingIndicator.remove();
                                            console.log('Removed pending open indicator for:', machineName);
                                        }

                                        // Insert opened indicator
                                        const openedIndicator = document.createElement('span');
                                        openedIndicator.textContent = '已打开';
                                        openedIndicator.dataset.opened = 'true';
                                        openedIndicator.dataset.machineName = machineName;
                                        openedIndicator.style.color = '#ffffff';
                                        openedIndicator.style.backgroundColor = '#28a745';
                                        openedIndicator.style.opacity = '0.9';
                                        openedIndicator.style.padding = '1px 4px';
                                        openedIndicator.style.borderRadius = '3px';
                                        openedIndicator.style.marginLeft = '4px';
                                        openedIndicator.style.fontSize = computedStyle.fontSize;
                                        openedIndicator.style.lineHeight = computedStyle.lineHeight;
                                        openedIndicator.style.display = 'inline !important';
                                        openedIndicator.style.visibility = 'visible';
                                        openedIndicator.style.marginTop = '7px';
                                        statusCell.appendChild(openedIndicator);
                                        console.log('Inserted opened indicator for:', machineName);
                                    } else {
                                        console.log('Auto-open aborted for:', machineName, 'Enabled:', autoOpenEnabled, 'Already opened:', autoOpenedDevices.has(machineName));
                                        // Remove pending indicator
                                        if (pendingIndicator.parentNode) {
                                            pendingIndicator.remove();
                                            console.log('Removed pending open indicator for:', machineName);
                                        }
                                    }
                                    autoOpenTimeouts.delete(machineName);
                                }, 60 * 1000); // 1 minute delay
                                autoOpenTimeouts.set(machineName, timeoutId);
                            } else if (autoOpenedDevices.has(machineName)) {
                                // Insert opened indicator for already opened devices
                                const openedIndicator = document.createElement('span');
                                openedIndicator.textContent = '已打开';
                                openedIndicator.dataset.opened = 'true';
                                openedIndicator.dataset.machineName = machineName;
                                openedIndicator.style.color = '#ffffff';
                                openedIndicator.style.backgroundColor = '#28a745';
                                openedIndicator.style.opacity = '0.9';
                                openedIndicator.style.padding = '1px 4px';
                                openedIndicator.style.borderRadius = '3px';
                                openedIndicator.style.marginLeft = '4px';
                                openedIndicator.style.fontSize = computedStyle.fontSize;
                                openedIndicator.style.lineHeight = computedStyle.lineHeight;
                                openedIndicator.style.display = 'inline !important';
                                openedIndicator.style.visibility = 'visible';
                                openedIndicator.style.marginTop = '7px';
                                statusCell.appendChild(openedIndicator);
                                console.log('Inserted opened indicator for previously opened device:', machineName);
                            } else {
                                console.log('Auto-open skipped:', machineName, 'Enabled:', autoOpenEnabled, 'Already opened:', autoOpenedDevices.has(machineName));
                            }
                        } else {
                            console.log('Time element not found for:', identifier);
                        }
                    } else {
                        console.log('No URL found for identifier:', identifier);
                    }
                } else {
                    console.log('No identifier matched in machine name:', machineName);
                }
            } else {
                // Handle connected devices
                const connectedSpan = statusCell.querySelector('span.text-sm');
                if (connectedSpan && connectedSpan.textContent.includes('Connected')) {
                    // Hide original Connected text
                    connectedSpan.style.display = 'none';
                    console.log('Hid original Connected text for:', machineName);

                    // Save original Connected text
                    const originalConnectedText = connectedSpan.textContent;
                    console.log('Saved original Connected text for:', machineName, originalConnectedText);

                    // Insert status indicator (green dot for online)
                    const statusIndicator = document.createElement('span');
                    statusIndicator.className = 'inline-block w-2 h-2 rounded-full bg-green-300 dark:bg-green-400 mr-2';
                    statusIndicator.dataset.statusIndicator = 'true';
                    statusIndicator.style.marginTop = '15px';
                    statusCell.appendChild(statusIndicator);
                    console.log('Inserted status indicator (green) for:', machineName);

                    // Insert link
                    const linkElement = document.createElement('a');
                    linkElement.href = `http://${machineName}.tail2c200.ts.net:5800/`;
                    linkElement.textContent = 'Connected';
                    linkElement.target = '_blank';
                    linkElement.dataset.processed = 'true';
                    const computedStyle = window.getComputedStyle(connectedSpan);
                    linkElement.style.color = computedStyle.color; // Match text-sm color
                    linkElement.style.fontSize = computedStyle.fontSize;
                    linkElement.style.fontFamily = computedStyle.fontFamily;
                    linkElement.style.fontWeight = computedStyle.fontWeight;
                    linkElement.style.lineHeight = computedStyle.lineHeight;
                    linkElement.style.textDecoration = 'underline';
                    linkElement.style.display = 'inline !important';
                    linkElement.style.opacity = '1';
                    linkElement.style.visibility = 'visible';
                    linkElement.style.pointerEvents = 'auto';
                    linkElement.style.zIndex = '1';
                    linkElement.style.position = 'relative';
                    linkElement.style.whiteSpace = 'nowrap';
                    linkElement.style.marginTop = '7px';
                    linkElement.style.marginLeft = '-5px';

                    // Insert link into statusCell
                    statusCell.appendChild(linkElement);
                    console.log('Inserted link for connected device:', machineName);
                    console.log('Link styles:', {
                        display: window.getComputedStyle(linkElement).display,
                        opacity: window.getComputedStyle(linkElement).opacity,
                        visibility: window.getComputedStyle(linkElement).visibility,
                        color: window.getComputedStyle(linkElement).color,
                        fontSize: window.getComputedStyle(linkElement).fontSize
                    });
                    console.log('Status cell HTML:', statusCell.outerHTML);

                    // Cancel any pending auto-open timeout and remove indicators
                    if (autoOpenTimeouts.has(machineName)) {
                        clearTimeout(autoOpenTimeouts.get(machineName));
                        autoOpenTimeouts.delete(machineName);
                        console.log('Cleared auto-open timeout for connected device:', machineName);
                    }
                    const pendingIndicator = statusCell.querySelector('span[data-pending-open="true"]');
                    if (pendingIndicator) {
                        pendingIndicator.remove();
                        console.log('Removed pending open indicator for connected device:', machineName);
                    }
                    const openedIndicator = statusCell.querySelector('span[data-opened="true"]');
                    if (openedIndicator) {
                        openedIndicator.remove();
                        console.log('Removed opened indicator for connected device:', machineName);
                    }
                } else {
                    console.log('Not a connected device or span not found for:', machineName);
                }
            }
        });
    }

    // Debounced processRows to prevent excessive calls
    const debouncedProcessRows = debounce(processRows, 100);

    // Run on page load and reset auto-opened devices
    window.addEventListener('load', () => {
        console.log('Page loaded, running processRows');
        autoOpenedDevices.clear(); // Reset on page load/refresh
        autoOpenTimeouts.forEach((timeoutId, machineName) => {
            clearTimeout(timeoutId);
            console.log('Cleared auto-open timeout on load for:', machineName);
        });
        autoOpenTimeouts.clear();
        injectToggleButton();
        processRows();
    });

    // Run after delays to catch dynamic content
    setTimeout(processRows, 1000);
    setTimeout(processRows, 2000);
    setTimeout(processRows, 3000);
    setTimeout(processRows, 4000);
    setTimeout(processRows, 5000);

    // Observe for dynamic changes
    const observer = new MutationObserver(mutations => {
        console.log('Mutation observed, reprocessing rows');
        debouncedProcessRows();
    });
    const tbody = document.querySelector('tbody') || document.body;
    if (tbody) {
        console.log('Observing:', tbody.tagName);
        observer.observe(tbody, { childList: true, subtree: true });
    } else {
        console.log('tbody not found, observing body');
        observer.observe(document.body, { childList: true, subtree: true });
    }
    // Retry finding tbody after delay
    setTimeout(() => {
        const tbodyRetry = document.querySelector('tbody');
        if (tbodyRetry && tbody !== tbodyRetry) {
            console.log('tbody found on retry, observing');
            observer.observe(tbodyRetry, { childList: true, subtree: true });
        } else {
            console.log('tbody still not found on retry');
        }
    }, 2000);
})();