- (void)triggerAntForestAutoClick:(WKWebView *)webView {
    NSString *jsCode = @"\
        (function() {\
            // 遍历网页中的按钮、链接、容器，精准匹配 '1T' 或 '抽能量' 字样\
            var elements = document.querySelectorAll('button, div, span, a, section');\
            for (var i = 0; i < elements.length; i++) {\
                var text = elements[i].innerText || elements[i].textContent;\
                if (text) {\
                    // 检查是否包含 1T 或 抽能量 关键字\
                    if (text.indexOf('1T') !== -1 || text.indexOf('抽能量') !== -1 || text.indexOf('抽1T') !== -1) {\
                        // 避免点到大容器，优先点里面具体的子按钮或直接触发点击\
                        elements[i].click();\
                        console.log('[AutoClicker] 成功触发 1T 能量抽取，匹配文字: ' + text.trim());\
                    }\
                }\
            }\
        })();\
    ";
    
    [webView evaluateJavaScript:jsCode completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"[AutoClicker] JS 执行失败: %@", error);
        }
    }];
}
