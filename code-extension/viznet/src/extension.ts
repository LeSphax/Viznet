import * as vscode from 'vscode';
import * as net from 'net';

export function activate(context: vscode.ExtensionContext) {
    const serverPath = '/tmp/vscode-file-open-pipe';

    // Create a client for the named pipe
    const client = net.createConnection(serverPath);

    // Handle connection errors
    client.on('error', (err) => {
        console.error('Named pipe error:', err);
    });

    // Subscribe to the event that fires when a text document is opened
    vscode.workspace.onDidOpenTextDocument((document) => {
        // Send the file path through the named pipe
        const filePath = document.uri.fsPath;
        client.write(`File opened: ${filePath}\n`);
    });

    // Push the client to the context's subscriptions so it's cleaned up on deactivation
    context.subscriptions.push({
        dispose: () => {
            client.end();
        }
    });
}

export function deactivate() {}
