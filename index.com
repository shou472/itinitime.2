<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>文化祭くじ（1日目）</title>
    <style>
        body {
            font-family: 'Helvetica Neue', Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #fdf6ec;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            text-align: center;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            max-width: 90%;
            width: 400px;
            position: relative;
        }
        h1 { color: #5c3a21; margin-bottom: 20px; font-size: 24px; }
        .qr-placeholder {
            width: 200px;
            height: 200px;
            background: #f5ebe0;
            margin: 20px auto;
            display: flex;
            justify-content: center;
            align-items: center;
            border: 4px solid #5c3a21;
            font-weight: bold;
            font-size: 14px;
            color: #5c3a21;
        }
        .result-box { display: none; }
        .rank { font-size: 36px; font-weight: bold; color: #d35400; margin-bottom: 15px; animation: pop 0.5s ease; }
        .prize { font-size: 30px; font-weight: bold; color: #5c3a21; margin-bottom: 25px; }
        .timer { color: #747d8c; font-size: 14px; background: #f1f2f6; padding: 10px; border-radius: 10px; }
        
        @keyframes pop {
            0% { transform: scale(0.5); opacity: 0; }
            100% { transform: scale(1); opacity: 1; }
        }

        /* 設定ボタンとモーダル */
        .settings-btn {
            position: absolute;
            top: 15px;
            right: 15px;
            background: none;
            border: none;
            color: #a4b0be;
            cursor: pointer;
            font-size: 14px;
            text-decoration: underline;
        }
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.5);
            justify-content: center;
            align-items: center;
            z-index: 100;
        }
        .modal-content {
            background: white;
            padding: 30px;
            border-radius: 15px;
            width: 300px;
            text-align: left;
        }
        .modal-content h3 { margin-top: 0; }
        .stock-item { display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 16px; font-weight: bold; }
        .close-btn { background: #747d8c; color: white; border: none; padding: 8px 15px; border-radius: 5px; cursor: pointer; margin-top: 15px; }
        .reset-btn { background: #d35400; color: white; border: none; padding: 8px 15px; border-radius: 5px; cursor: pointer; margin-top: 15px; float: right; }
    </style>
</head>
<body>

<div class="container">
    <button class="settings-btn" onclick="openSettings()">設定</button>

    <!-- 初期QR案内画面 -->
    <div id="qr-screen">
        <h1>次の方どうぞ！</h1>
        <div class="qr-placeholder">
            <span style="padding: 10px;">QRコードを<br>スキャンしてください</span>
        </div>
        <p style="color:#5c3a21; margin-bottom:20px;">スマホで読み込むと、結果が表示されます！</p>
    </div>

    <!-- 結果表示画面 -->
    <div id="result-screen" class="result-box">
        <h1>抽選結果</h1>
        <div id="result-rank" class="rank">あたり！</div>
        <div id="result-prize" class="prize">抽選中...</div>
        <div id="result-timer" class="timer">10秒後に画面が戻ります</div>
    </div>
</div>

<!-- 設定モーダル -->
<div id="settings-modal" class="modal">
    <div class="modal-content">
        <h3>残り個数（1日目在庫）</h3>
        <div class="stock-item"><span>明和町カレー:</span> <span><span id="stock-curry">5</span>個</span></div>
        <div class="stock-item"><span>チョコ棒:</span> <span><span id="stock-choco">60</span>本</span></div>
        <button class="close-btn" onclick="closeSettings()">閉じる</button>
        <button class="reset-btn" onclick="resetStock()">リセット</button>
    </div>
</div>

<script>
    // 1日目の初期在庫（明和カレー5個、チョコ棒60本）
    const INITIAL_STOCK = { curry: 5, choco: 60 };
    let stock = JSON.parse(localStorage.getItem('day1_lottery_stock')) || { ...INITIAL_STOCK };
    let returnTimeout;
    let countdownInterval;

    function updateStockDisplay() {
        document.getElementById('stock-curry').innerText = stock.curry;
        document.getElementById('stock-choco').innerText = stock.choco;
        localStorage.setItem('day1_lottery_stock', JSON.stringify(stock));
    }

    function openSettings() {
        updateStockDisplay();
        document.getElementById('settings-modal').style.display = 'flex';
    }
    function closeSettings() {
        document.getElementById('settings-modal').style.display = 'none';
    }
    function resetStock() {
        if(confirm('残り個数を初期状態（カレー5個・チョコ棒60本）に戻しますか？')) {
            stock = { ...INITIAL_STOCK };
            updateStockDisplay();
        }
    }

    window.onload = function() {
        drawDay1Lottery();
    };

    function drawDay1Lottery() {
        let rank = "";
        let prize = "";

        // 1. まず全体の在庫が完全に0かチェック
        if (stock.curry <= 0 && stock.choco <= 0) {
            rank = "終了";
            prize = "本日の景品はすべて終了しました";
        } else {
            // 2. 確率判定（カレー30%、チョコ棒70%）
            let rand = Math.random() * 100;

            if (rand < 30) {
                // 30%の枠（カレー優先）
                if (stock.curry > 0) {
                    rank = "大あたり！ 🎉";
                    prize = "明和町カレー";
                    stock.curry--;
                } else {
                    // カレーが品切れならチョコ棒へ
                    rank = "あたり！ 🍫";
                    prize = "チョコ棒";
                    stock.choco--;
                }
            } else {
                // 70%の枠（チョコ棒優先）
                if (stock.choco > 0) {
                    rank = "あたり！ 🍫";
                    prize = "チョコ棒";
                    stock.choco--;
                } else {
                    // チョコ棒が品切れなら残っているカレーへ
                    rank = "大あたり！ 🎉";
                    prize = "明和町カレー";
                    stock.curry--;
                }
            }
        }

        // 在庫データを保存・表示更新
        updateStockDisplay();

        // 結果画面を表示
        document.getElementById('result-rank').innerText = rank;
        document.getElementById('result-prize').innerText = prize;
        document.getElementById('qr-screen').style.display = 'none';
        document.getElementById('result-screen').style.display = 'block';

        // 10秒カウントダウンと自動リターン
        let timeLeft = 10;
        document.getElementById('result-timer').innerText = `⚠️ ${timeLeft}秒後に画面が戻ります`;
        
        clearInterval(countdownInterval);
        countdownInterval = setInterval(() => {
            timeLeft--;
            if(timeLeft > 0) {
                document.getElementById('result-timer').innerText = `⚠️ ${timeLeft}秒後に画面が戻ります`;
            } else {
                clearInterval(countdownInterval);
            }
        }, 1000);

        clearTimeout(returnTimeout);
        returnTimeout = setTimeout(() => {
            backToQR();
        }, 10000);
    }

    function backToQR() {
        document.getElementById('result-screen').style.display = 'none';
        document.getElementById('qr-screen').style.display = 'block';
    }

    // 初回読み込み時に表示をセット
    updateStockDisplay();
</script>
</body>
</html>
