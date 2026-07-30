<?php
/**
 * IPOSB — Assign consignment to mobile driver (J&T-style dispatch).
 * Calls Driver API POST /dispatch/assign which updates MySQL + FCM.
 *
 * Place under FMS web root or open via local PHP server for demos.
 * Configure $DRIVER_API_BASE and $DISPATCH_API_KEY to match driver-api/.env
 */
session_start();
$page_title = 'IPOSB Assign Driver';

$DRIVER_API_BASE = getenv('IPOSB_DRIVER_API') ?: 'http://127.0.0.1:3080';
$DISPATCH_API_KEY = getenv('IPOSB_DISPATCH_KEY') ?: 'iposb-dispatch-dev-key';

$message = null;
$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $cnNo = trim($_POST['cn_no'] ?? '');
  $firebaseUid = trim($_POST['firebase_uid'] ?? '');
  $jobType = trim($_POST['job_type'] ?? 'delivery');

  if ($cnNo === '' || $firebaseUid === '') {
    $error = 'CN No and Driver Firebase UID are required.';
  } else {
    $payload = json_encode([
      'cnNo' => $cnNo,
      'firebaseUid' => $firebaseUid,
      'jobType' => $jobType,
    ]);

    $ch = curl_init(rtrim($DRIVER_API_BASE, '/') . '/dispatch/assign');
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
      $error = 'API connection failed: ' . $cerr;
    } else {
      $json = json_decode($raw, true);
      if ($code >= 200 && $code < 300 && !empty($json['ok'])) {
        $message = 'Assigned CN ' . htmlspecialchars($cnNo) .
          ' to driver (id ' . intval($json['driverId']) . '). Push: ' .
          (!empty($json['fcm']['skipped']) ? 'skipped (no FCM)' : 'queued');
      } else {
        $error = 'Assign failed (' . $code . '): ' .
          htmlspecialchars($json['error'] ?? $raw);
      }
    }
  }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title><?php echo htmlspecialchars($page_title); ?></title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 560px; margin: 40px auto; }
    label { display: block; margin-top: 12px; font-weight: bold; }
    input, select { width: 100%; padding: 8px; margin-top: 4px; }
    button { margin-top: 16px; padding: 10px 16px; }
    .ok { color: #0a7; }
    .err { color: #c00; }
    .hint { color: #666; font-size: 13px; }
  </style>
</head>
<body>
  <h1>Assign Driver</h1>
  <p class="hint">Dispatcher tool — writes assignment on MySQL master and notifies the Flutter driver app via FCM.</p>

  <?php if ($message): ?><p class="ok"><?php echo $message; ?></p><?php endif; ?>
  <?php if ($error): ?><p class="err"><?php echo $error; ?></p><?php endif; ?>

  <form method="post">
    <label>Consignment No (CN / AWB)</label>
    <input name="cn_no" maxlength="8" required placeholder="e.g. 2009103" />

    <label>Driver Firebase UID</label>
    <input name="firebase_uid" required value="demo-driver-kk" />
    <p class="hint">Demo driver uid from integration seed: demo-driver-kk</p>

    <label>Job type</label>
    <select name="job_type">
      <option value="pickup">Pickup</option>
      <option value="delivery" selected>Delivery</option>
    </select>

    <button type="submit">Assign &amp; Notify</button>
  </form>
</body>
</html>
