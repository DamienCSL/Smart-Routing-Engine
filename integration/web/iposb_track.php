<?php
/**
 * IPOSB — Customer order tracking (public).
 * Enter CN/AWB → shows friendly status + timeline from Driver API.
 */
$DRIVER_API_BASE = getenv('IPOSB_DRIVER_API') ?: 'http://127.0.0.1:3080';
$page_title = 'IPOSB Track Order';

$cnNo = trim($_GET['cn'] ?? $_POST['cn'] ?? '');
$data = null;
$error = null;

if ($cnNo !== '') {
  $url = rtrim($DRIVER_API_BASE, '/') . '/tracking/' . rawurlencode($cnNo);
  $ch = curl_init($url);
  curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 15,
  ]);
  $raw = curl_exec($ch);
  $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  $cerr = curl_error($ch);
  curl_close($ch);

  if ($cerr) {
    $error = 'Cannot reach tracking API: ' . $cerr;
  } else {
    $json = json_decode($raw, true);
    if ($code >= 200 && $code < 300 && is_array($json)) {
      $data = $json;
    } else {
      $error = htmlspecialchars($json['error'] ?? ('HTTP ' . $code));
    }
  }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title><?php echo htmlspecialchars($page_title); ?></title>
  <style>
    :root { --ink: #1a1a1a; --muted: #666; --line: #ddd; --ok: #0a7; --bg: #f7f7f5; }
    body { font-family: Georgia, 'Times New Roman', serif; max-width: 560px; margin: 0 auto; padding: 32px 20px; background: var(--bg); color: var(--ink); }
    h1 { font-size: 1.75rem; margin: 0 0 8px; letter-spacing: 0.02em; }
    .sub { color: var(--muted); font-size: 0.95rem; margin-bottom: 24px; }
    form { display: flex; gap: 8px; margin-bottom: 24px; }
    input { flex: 1; padding: 12px; border: 1px solid var(--line); font-size: 1rem; }
    button { padding: 12px 18px; border: 0; background: var(--ink); color: #fff; cursor: pointer; }
    .card { background: #fff; border: 1px solid var(--line); padding: 20px; }
    .label { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); }
    .status { font-size: 1.4rem; font-weight: bold; margin: 4px 0 12px; color: var(--ok); }
    .meta { font-size: 0.9rem; color: var(--muted); margin-bottom: 16px; }
    ol { list-style: none; padding: 0; margin: 0; }
    li { border-top: 1px solid var(--line); padding: 12px 0; }
    li .t { font-weight: bold; }
    li .d { font-size: 0.85rem; color: var(--muted); }
    .err { color: #b00020; margin-bottom: 16px; }
  </style>
</head>
<body>
  <h1>Track your order</h1>
  <p class="sub">Enter your consignment / AWB number to see live status.</p>

  <form method="get">
    <input name="cn" maxlength="16" required placeholder="e.g. 2009103" value="<?php echo htmlspecialchars($cnNo); ?>" />
    <button type="submit">Track</button>
  </form>

  <?php if ($error): ?><p class="err"><?php echo $error; ?></p><?php endif; ?>

  <?php if ($data): ?>
  <div class="card">
    <div class="label">Current status</div>
    <div class="status"><?php echo htmlspecialchars($data['customerLabel'] ?? ''); ?></div>
    <div class="meta">
      CN <?php echo htmlspecialchars($data['cnNo'] ?? ''); ?>
      <?php if (!empty($data['destination'])): ?>
        · To <?php echo htmlspecialchars($data['destination']); ?>
      <?php endif; ?>
    </div>
    <div class="label">Timeline</div>
    <ol>
      <?php foreach (($data['timeline'] ?? []) as $row): ?>
      <li>
        <div class="t"><?php echo htmlspecialchars($row['customerLabel'] ?? $row['statusCode']); ?></div>
        <div class="d">
          <?php echo htmlspecialchars($row['at'] ?? ''); ?>
          <?php if (!empty($row['location'])): ?> · <?php echo htmlspecialchars($row['location']); ?><?php endif; ?>
          <?php if (!empty($row['note'])): ?> — <?php echo htmlspecialchars($row['note']); ?><?php endif; ?>
        </div>
      </li>
      <?php endforeach; ?>
    </ol>
  </div>
  <?php endif; ?>
</body>
</html>
