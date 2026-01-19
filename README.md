# SwiftFanfou

A Swift library for interacting with the [Fanfou API](https://github.com/FanfouAPI/FanFouAPIDoc/wiki/Apicategory) using OAuth 1.0 authentication.

## Features

- OAuth 1.0 authentication flow, xAuth authentication
- Handles the Fanfou HTTPS to HTTP signature quirk automatically
- No external dependencies

## Usage

### Initialize the client

```swift
let fanfou = SwiftFanfou(
    consumerKey: "your_consumer_key",
    consumerSecret: "your_consumer_secret"
)
```

If you already have access tokens:

```swift
let fanfou = SwiftFanfou(
    consumerKey: "your_consumer_key",
    consumerSecret: "your_consumer_secret",
    oauthToken: "your_oauth_token",
    oauthTokenSecret: "your_oauth_token_secret"
)
```

### Authentication

#### xAuth (Username/Password)

```swift
fanfou.xAuth(userName: "username", password: "password") { result in
    switch result {
    case .success(let credentials):
        print("Token: \(credentials.token)")
        print("Secret: \(credentials.secret)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

#### OAuth Flow

1. Request a token and get authorization URL:

```swift
fanfou.requestToken(callbackURL: "YourApp://callback") { result in
    switch result {
    case .success(let url):
        // Open this URL in a browser for user authorization
        print("Open URL: \(url)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

2. After user authorizes, exchange for access token:

```swift
fanfou.accessToken { result in
    switch result {
    case .success(let credentials):
        print("Token: \(credentials.token)")
        print("Secret: \(credentials.secret)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Making API Requests

#### Standard requests

```swift
fanfou.request(
    "https://api.fanfou.com/statuses/home_timeline.json",
    method: "GET",
    parameters: ["count": 20]
) { result in
    // Handle result
}
```

#### Upload images

```swift
guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

fanfou.request(
    "https://api.fanfou.com/photos/upload.json",
    parameters: ["status": "Hello Fanfou!"],
    image: imageData,
    name: "photo"
) { result in
    // Handle result
}
```

#### Update profile image

```swift
guard let imageData = profileImage.jpegData(compressionQuality: 0.8) else { return }

fanfou.request(
    "https://api.fanfou.com/account/update_profile_image.json",
    parameters: [:],
    image: imageData,
    name: "image"  // Use "image" for profile updates
) { result in
    // Handle result
}
```

## API Examples

### Get home timeline

```swift
fanfou.request(
    "https://api.fanfou.com/statuses/home_timeline.json",
    method: "GET",
    parameters: ["count": 20, "format": "html"]
) { result in
    // Handle result
}
```

### Post a status

```swift
fanfou.request(
    "https://api.fanfou.com/statuses/update.json",
    method: "POST",
    parameters: ["status": "Hello from SwiftFanfou!"]
) { result in
    // Handle result
}
```

### Get user info

```swift
fanfou.request(
    "https://api.fanfou.com/users/show.json",
    method: "GET",
    parameters: ["id": "username"]
) { result in
    // Handle result
}
```

### Unfavorite a status
```swift
fanfou.request(
    "https://api.fanfou.com/favorites/destroy/\(statusId).json",
    method: "POST",
) { result in
    // Handle result
}
```

## License

MIT License
Copyright (c) 2026 Maundy Liu
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
