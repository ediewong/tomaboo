import AppKit

/// 菜单栏标签：「学习 (44:54)」——类别名 + 胶囊时间，时间文字镂空。
/// 模板图片，系统会按菜单栏深浅色自动着色。
func menuBarPill(name: String, time: String) -> NSImage {
    let height: CGFloat = 16, padX: CGFloat = 6, gap: CGFloat = 5
    let nameText = NSAttributedString(string: name, attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.black,
    ])
    let timeText = NSAttributedString(string: time, attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.black,
    ])
    let nameSize = nameText.size(), timeSize = timeText.size()
    let nameWidth = name.isEmpty ? 0 : ceil(nameSize.width) + gap
    let pillWidth = ceil(timeSize.width) + padX * 2

    let image = NSImage(size: NSSize(width: nameWidth + pillWidth, height: height), flipped: false) { _ in
        nameText.draw(at: NSPoint(x: 0, y: (height - nameSize.height) / 2))
        let pill = NSRect(x: nameWidth, y: 0, width: pillWidth, height: height)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: pill, xRadius: height / 2, yRadius: height / 2).fill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.destinationOut)
        timeText.draw(at: NSPoint(x: pill.minX + padX, y: (height - timeSize.height) / 2))
        return true
    }
    image.isTemplate = true
    return image
}

/// 菜单栏空闲图标：番茄剪影（模板图片，随菜单栏深浅色着色）
let tomatoIcon: NSImage = {
    let image = NSImage(data: Data(tomatoSVG.utf8))!
    image.size = NSSize(width: 17, height: 17)
    image.isTemplate = true
    return image
}()

private let tomatoSVG = """
<svg width="200" height="201" viewBox="0 0 200 201" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M92.4688 0C97.7694 3.12114 98.9515 7.04948 101.021 12.4756C102.384 16.0488 105.359 22.5916 110.207 20.1953C118.067 15.9202 119.738 -0.910875 128.809 0.707031C139.241 2.56767 123.651 20.0619 120.819 23.3584C130.404 18.2689 138.663 11.6152 147.881 7.1582C143.41 13.7383 140.847 16.1796 135.385 21.834L130.048 27.7422C124.162 35.1041 124.244 39.8421 132.204 45.6768C140.56 51.7998 150.756 54.801 160.074 59.0908C179.746 68.2635 195.868 84.1182 199.041 106.377C201.1 120.82 198.908 145.132 189.984 157.635C188.346 159.931 185.338 162.792 184.199 164.409C181.033 167.295 178.783 169.236 175.326 171.823C161.451 181.07 143.611 190.205 127.925 195.88C111.063 201.975 87.8838 200.699 70.2256 197.17C65.897 196.286 61.5997 195.254 57.3408 194.079C56.3554 193.813 51.1566 192.301 50.457 192.25C43.4888 189.048 35.0647 186.69 29.208 181.479C21.2242 174.378 15.0027 165.041 9.32422 156.061C0.424093 140.834 -1.21835 136 0.733398 118.822C3.03051 107.373 5.25819 102.122 9.43555 91.5166C11.4312 88.4679 15.724 80.308 17.8105 76.7031C19.7806 74.0509 21.786 71.4245 23.8262 68.8262C42.9027 44.895 59.0576 43.7878 87.2402 40.5635C82.3652 35.9964 63.6804 17.4915 68.5898 10.9121C70.3253 10.3102 72.0519 11.267 73.626 12.0088L77.9385 14.3926C81.0708 16.2976 84.3573 18.2374 87.4512 20.1816C85.9429 10.7747 83.8312 6.24699 92.4688 0ZM72.9512 136.13C73.0004 139.127 73.0816 140.345 73.7256 143.339C76.8233 144.173 79.3845 144.597 82.5293 145.129L87.1885 145.848C95.8934 147.127 102.786 147.939 111.576 148.64C108.489 143.206 107.831 141.01 101.223 139.519C95.0093 138.117 88.8649 137.549 82.5391 136.967C79.358 136.496 76.1596 136.338 72.9512 136.13ZM140.204 125.798C139.852 118.071 132.884 117.518 127.202 117.737C123.307 123.045 120.691 129.568 127.296 134.136C129.488 135.649 132.661 136.482 135.256 135.742C137.721 133.148 140.373 129.449 140.204 125.798ZM94.916 99.9727C91.2339 106.801 84.5657 118.003 85.375 126.283C85.5582 128.155 88.6348 128.694 90.2666 129.082C92.3897 129.556 94.7576 130.419 96.6299 129.366C99.5588 125.607 100.052 103.484 96.5264 100.3C96.0304 100.196 95.4012 100.041 94.916 99.9727ZM50.4209 109.453C48.5518 111.573 48.4198 112.188 47.1211 114.542C43.2754 121.514 51.3085 129.438 58.21 127.548C60.8006 124.72 63.6577 121.083 63.2598 117.065C62.5428 109.821 55.9732 109.299 50.4209 109.453Z" fill="#FEFDFD"/>
</svg>
"""
