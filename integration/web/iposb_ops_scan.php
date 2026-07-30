<?php
/**
 * IPOSB Sprint 1 — Ops scan desk (hub / sort / storekeeper / OFD helper).
 * Uses POST /ops/scan with X-Dispatch-Key.
 */
$DRIVER_API_BASE = getenv('IPOSB_DRIVER_API') ?: 'http://127.0.0.1:3080';
$DISPATCH_API_KEY = getenv('IPOSB_DISPATCH_KEY') ?: 'iposb-dispatch-dev-key';
$page_title = 'IPOSB Ops Scan';

$message = null;
$error = null;
$label = null;

$scans = [
  'PKU' => 'Pickup from seller',
  'ARR' => 'Hub arrival',
  'SRT' => 'Sort SBH325/326',
  'SHB' => 'Storekeeper receive',
  'OFD' => 'Out for delivery',
  'DRS' => 'With courier (DRS)',
  'POD' => 'Delivered (POD)',
  'UND' => 'Undelivered',
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $action = $_POST['action'] ?? 'scan';
  $cnNo = trim($_POST['cn_no'] ?? '');

  if ($action === 'create') {
    $payload = json_encode([
      'recipientName' => trim($_POST['recipient'] ?? 'Demo Buyer'),
      'address' => trim($_POST['address'] ?? 'Demo address KK'),
      'origin' => trim($_POST['origin'] ?? 'BKI'),
      'dest' => trim($_POST['dest'] ?? 'BKI'),
    ]);
    $ch = curl_init(rtrim($DRIVER_API_BASE, '/') . '/demo/orders');
    curl_setopt_array($ch, [
      CURLOPT_POST => true,
      CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'X-Dispatch-Key: ' . $DISPATCH_API_KEY,
      ],
      CURLOPT_POSTFIELDS => $payload,
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_TIMEOUT => 20,
    ]);
    $raw = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $cerr = curl_error($ch);
    curl_close($ch);
    if ($cerr) {
      $error = $cerr;
    } else {
      $json = json_decode($raw, true);
      if ($code >= 200 && $code < 300 && !empty($json['ok'])) {
        $message = 'Created demo CN ' . htmlspecialchars($json['cnNo']);
        $cnNo = $json['cnNo'];
      } else {
        $error = htmlspecialchars($json['error'] ?? $raw);
      }
    }
  }

  if ($action === 'scan' && $cnNo !== '') {
    $status = trim($_POST['status'] ?? '');
    $payload = json_encode([
      'cnNo' => $cnNo,
      'status' => $status,
      'note' => trim($_POST['note'] ?? ''),
      'actorName' => trim($_POST['actor'] ?? 'ops desk'),
    ]);
    $ch = curl_init(rtrim($DRIVER_API_BASE, '/') . '/ops/scan');
    curl_setopt_array($ch, [
      CURLOPT_POST => true,
      CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'X-Dispatch-Key: ' . $DISPATCH_API_KEY,
      ],
      CURLOPT_POSTFIELDS => $payload,
      CURLOPT_RETURNTRANSFER => true,
      CURLOPT_TIMEOUT => 20,
    ]);
    $raw = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $cerr = curl_error($ch);
    curl_close($ch);
    if ($cerr) {
      $error = $cerr;
    } else {
      $json = json_decode($raw, true);
      if ($code >= 200 && $code < 300 && !empty($json['ok'])) {
        $message = 'Scanned ' . htmlspecialchars($status) . ' → customer: ' .
          htmlspecialchars($json['customerLabel'] ?? '');
      } else {
        $error = htmlspecialchars($json['error'] ?? $raw);
      }
    }
  }

  if ($cnNo !== '') {
    $labelUrl = rtrim($DRIVER_API_BASE, '/') . '/labels/' . rawurlencode($cnNo);
    $ch = curl_init($labelUrl);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10]);
    $lraw = curl_exec($ch);
    curl_close($ch);
    $label = json_decode($lraw, true);
  }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title><?php echo htmlspecialchars($page_title); ?></title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 640px; margin: 32px auto; padding: 0 16px; }
    label { display: block; margin-top: 12px; font-weight: bold; }
    input, select, textarea { width: 100%; padding: 8px; margin-top: 4px; box-sizing: border-box; }
    button { margin-top: 14px; padding: 10px 16px; }
    .ok { color: #0a7; } .err { color: #c00; }
    .box { border: 1px solid #ddd; padding: 16px; margin-top: 24px; }
    img.qr { width: 180px; height: 180px; }
    .hint { color: #666; font-size: 13px; }
  </style>
</head>
<body>
  <h1>Ops Scan Desk</h1>
  <p class="hint">Sprint 1 — create a demo CN, print/show QR, scan each hop. Customer track: <a href="iposb_track.php">iposb_track.php</a></p>

  <?php if ($message): ?><p class="ok"><?php echo $message; ?></p><?php endif; ?>
  <?php if ($error): ?><p class="err"><?php echo $error; ?></p><?php endif; ?>

  <div class="box">
    <h2>1. Create demo order</h2>
    <form method="post">
      <input type="hidden" name="action" value="create" />
      <label>Recipient</label>
      <input name="recipient" value="Demo Buyer" />
      <label>Address</label>
      <input name="address" value="Likas, Kota Kinabalu" />
      <label>Origin / Dest loc</label>
      <input name="origin" value="BKI" style="width:48%;display:inline-block" />
      <input name="dest" value="BKI" style="width:48%;display:inline-block;float:right" />
      <button type="submit">Create CN + BDE</button>
    </form>
  </div>

  <div class="box">
    <h2>2. Scan barcode / CN</h2>
    <form method="post">
      <input type="hidden" name="action" value="scan" />
      <label>CN No (or paste from QR)</label>
      <input name="cn_no" required value="<?php echo htmlspecialchars($_POST['cn_no'] ?? ($label['cnNo'] ?? '')); ?>" />
      <label>Scan type</label>
      <select name="status">
        <?php foreach ($scans as $code => $labelText): ?>
          <option value="<?php echo $code; ?>"><?php echo $code; ?> — <?php echo htmlspecialchars($labelText); ?></option>
        <?php endforeach; ?>
      </select>
      <label>Note</label>
      <input name="note" placeholder="optional" />
      <label>Actor</label>
      <input name="actor" value="hub desk" />
      <button type="submit">Post scan</button>
    </form>
  </div>

  <?php if (!empty($label['dataUrl'])): ?>
  <div class="box">
    <h2>QR label</h2>
    <p>CN <strong><?php echo htmlspecialchars($label['cnNo']); ?></strong> — scan with the Flutter app</p>
    <img class="qr" src="<?php echo htmlspecialchars($label['dataUrl']); ?>" alt="QR" />
  </div>
  <?php endif; ?>
</body>
</html>
