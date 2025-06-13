# 📁 File API Microservice

A lightweight, Dockerized file API for programmatic file and folder operations — including upload, delete, rename, and optional public exposure of files and folders. Built for workflows like n8n and other automation systems.

---

## 🔐 Authentication

All modifying endpoints require a bearer token in the request header:

```
Authorization: Bearer YOUR_TOKEN
```

---

## 🔤 Path & Naming Rules

When creating folders or uploading files, the following naming restrictions apply:

- **Allowed characters**: Only letters, numbers, dashes, and underscores
  - ✅ `my-folder`, `project_123`, `reports2025`
- **Prohibited characters**: Spaces, dots, slashes, and special characters
  - ❌ `my folder`, `project.files`, `reports/2025`, `data$info`
- **URL safety**: Folder names are used in URLs, so they must be URL-safe
- **Error handling**: Invalid names will return a 400 status code with message "Invalid folder name"

These restrictions help ensure consistent behavior across different operating systems and web environments.

---

## 📦 Endpoints

### 1. **Create Folder**

**POST** `/mkdir`

**Headers:**

- `Authorization: Bearer <token>`

**Body:**

```json
{
  "folder": "desired-folder-name",
  "expose": true  // optional, defaults to false
}
```

**Response:**

```json
{
  "status": "ok",
  "action": "folder_created",
  "visibility": "exposed" | "hidden",
  "url": "https://yourdomain.com/public/desired-folder-name/" | null,
  "folder": "desired-folder-name",
  "file": null,
  "message": "Folder created"
}
```

---

### 2. **Upload File**

**POST** `/upload`

**Headers (Option A - Binary):**

- `Authorization: Bearer <token>`
- `Content-Type: application/octet-stream`

**Body:**

- Raw file stream

**Headers (Option B - JSON base64):**

- `Content-Type: application/json`

**Body:**

```json
{
  "folder": "myfolder",
  "filename": "file.jpg",
  "base64": "BASE64_ENCODED_STRING",
  "mimetype": "image/jpeg",
  "expose": true  // optional, if true: create folder and expose it
}
```

**Behavior:**

- Automatically creates folder if it doesn't exist
- Optionally exposes the folder on upload if `expose` is true

**Response:**

```json
{
  "status": "ok",
  "action": "file_uploaded",
  "visibility": "exposed" | "hidden",
  "url": "https://yourdomain.com/public/myfolder/file.jpg" | null,
  "folder": "myfolder",
  "file": "file.jpg",
  "message": "File uploaded"
}
```

---

### 3. **Delete File or Folder**

**DELETE** `/delete/:folder/:filename?`

**Headers:**

- `Authorization: Bearer <token>`

**Response (File):**

```json
{
  "status": "ok",
  "action": "file_deleted",
  "visibility": "hidden",
  "url": null,
  "folder": "myfolder",
  "file": "file.jpg",
  "message": "File deleted"
}
```

**Response (Folder):**

```json
{
  "status": "ok",
  "action": "folder_deleted",
  "visibility": "hidden",
  "url": null,
  "folder": "myfolder",
  "file": null,
  "message": "Folder and contents deleted"
}
```

---

### 4. **Expose Folder**

**POST** `/expose/:folder`

**Headers:**

- `Authorization: Bearer <token>`

**Response:**

```json
{
  "status": "ok",
  "action": "folder_exposed",
  "visibility": "exposed",
  "url": "https://yourdomain.com/public/myfolder/",
  "folder": "myfolder",
  "file": null,
  "message": "Folder is now public"
}
```

---

### 5. **Unexpose Folder**

**POST** `/unexpose/:folder`

**Headers:**

- `Authorization: Bearer <token>`

**Response:**

```json
{
  "status": "ok",
  "action": "folder_unexposed",
  "visibility": "hidden",
  "url": null,
  "folder": "myfolder",
  "file": null,
  "message": "Folder is no longer public"
}
```

---

### 6. **Rename File or Folder**

**PATCH** `/rename`

**Headers:**

- `Authorization: Bearer <token>`

**Body:**

```json
{
  "type": "file" | "folder",
  "folder": "myfolder",
  "filename": "oldname.jpg",   // required if type is "file"
  "newName": "newname.jpg"
}
```

**Response:**

```json
{
  "status": "ok",
  "action": "renamed",
  "visibility": "exposed" | "hidden",
  "url": "https://yourdomain.com/public/myfolder/newname.jpg" | null,
  "folder": "myfolder",
  "file": "newname.jpg" | null,
  "message": "Renamed successfully"
}
```

---

### 7. **List Folder Contents**

**GET** `/list/:folder`

**Headers:**

- `Authorization: Bearer <token>`

**Response:**

```json
{
  "status": "ok",
  "action": "folder_listed",
  "visibility": "exposed" | "hidden",
  "url": "https://yourdomain.com/public/myfolder/" | null,
  "folder": "myfolder",
  "file": null,
  "message": "Folder listed",
  "files": [
    {
      "name": "file1.jpg",
      "size": 12345,
      "modified": "2025-06-12T17:03:00.000Z"
    }
  ]
}
```

---

### 8. **List All Folders**

**GET** `/list`

**Headers:**

- `Authorization: Bearer <token>`

**Response:**

```json
{
  "status": "ok",
  "action": "root_listed",
  "visibility": null,
  "url": null,
  "folder": null,
  "file": null,
  "message": "Folders listed",
  "folders": [
    {
      "name": "workflow-123",
      "visibility": "exposed",
      "url": "https://yourdomain.com/public/workflow-123/"
    },
    {
      "name": "pending-review",
      "visibility": "hidden",
      "url": null
    }
  ]
}
```

---

### 9. **Serve Public File**

**GET** `/public/:folder/:filename`

No auth required. Returns raw file bytes.

---

## 🚀 Deployment

Docker image TBD. Runs as a single container. Will serve static public files via `/public`, and provide the JSON API on the same port.

---

## 🛠 Roadmap Ideas

- Token management via config file or environment var
- Expiring links or TTL-based cleanup
- File size limits
- Disk usage stats

---

MIT licensed. Built for automation.
