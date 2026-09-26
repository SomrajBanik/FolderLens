# FolderLens

FolderLens is a small Windows folder browser that turns a chosen directory into a clean, local web page. It is designed for quickly browsing mixed collections of documents, media, code, archives, and other files without installing a separate desktop catalog app.

## Why FolderLens

- **Lightweight:** a PowerShell script, a batch launcher, and one small SVG icon. It uses Windows PowerShell, the built-in .NET HTTP listener, and your existing browser; there are no package installs, databases, background services, or third-party runtimes.
- **Your files stay local:** the page and file previews are served from a local web server on your PC. FolderLens does not upload your collection to a cloud service. Files are written to the selected folder only when you explicitly add them through the page.
- **Folder boundary checks:** file and upload paths are resolved against their actual Windows filesystem targets. Links that point outside the selected folder are not exposed or used as upload destinations.
- **Works with mixed folders:** it catalogs files recursively, keeps the folder hierarchy visible, and lets you sort by name, modified date, or size.
- **Uses apps you actually have:** "Open with..." lists Windows-registered apps for the selected file type, along with the Windows default app.
- **Easy to use:** includes browser previews for common images, PDFs, text, audio, and video, a resizable folder tree, drag-and-drop file adding, and a light/dark appearance switch.

## Run it

1. Download or clone this repository to a Windows PC.
2. Double-click `FolderLens.bat` to choose a folder and open its catalog.
3. Or pass the folder path directly:

   ```powershell
   .\FolderLens.bat "C:\Users\YourName\Documents"
   ```

The script uses Windows PowerShell and opens the page in Microsoft Edge's app-style window when Edge is found. Otherwise, it opens your default browser. Close the page to stop the local server.

You can also start it directly from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FolderLens.ps1 "C:\Path\To\Folder"
```

Running `FolderLens.ps1` without a folder argument opens Windows' modern Explorer-style folder picker, initially at the script's own folder. The picker can be resized and includes the usual navigation locations and folder listing.

## Using the page

- Browse the folder cards or open **Folder tree** to navigate the hierarchy. Search folders and files, expand or collapse the tree, and drag the divider to resize it; use its `x` button to close it.
- Choose **Preview** for supported file types. Other types get a clear explanation and can be opened with a registered app.
- Choose **Open with...** to select an app registered with Windows for that file type, or use the Windows default.
- Add files with the folder's add card, using the file picker or drag and drop.
- Sort by name, modified date, or file size, and toggle the light/dark theme.
- Use **Refresh folder** to rescan changes made outside the page.

## Requirements and notes

- Windows with Windows PowerShell 5.1 or later.
- A modern browser; Microsoft Edge is preferred when installed.
- FolderLens binds its local HTTP server to `http://localhost:8765/`. If that port is already in use, close the other local service or change `$port` near the top of `FolderLens.ps1`.
- Browser previews depend on the browser supporting the file's media format. **Open with...** remains available for files that cannot be previewed.
