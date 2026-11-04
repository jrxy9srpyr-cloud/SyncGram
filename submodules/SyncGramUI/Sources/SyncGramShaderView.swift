import Foundation
import UIKit
import QuartzCore
import Metal
import TelegramCore

private let syncGramShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 resolution;
    float2 params;     // x: time, y: style
    float4 params2;    // x: dark, y: intensity
    float4 accent;     // rgb: theme accent
    float4 baseTint;   // rgb: theme background
};

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vs_main(uint vid [[vertex_id]]) {
    float2 position = float2(vid == 1 ? 3.0 : -1.0, vid == 2 ? 3.0 : -1.0);
    VertexOut out;
    out.position = float4(position, 0.0, 1.0);
    return out;
}

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * valueNoise(p);
        p = p * 2.03 + float2(17.1, 9.7);
        amplitude *= 0.5;
    }
    return value;
}

float3 auroraStyle(float2 p, float t, float3 base, float3 warm, float3 cool, float3 accent) {
    float2 q = p * 1.35 + float2(0.0, 0.15);
    float n1 = fbm(q + float2(t * 0.55, -t * 0.28));
    float n2 = fbm(q * 1.7 + float2(-t * 0.42, t * 0.36) + n1 * 1.6);
    float glow = smoothstep(0.30, 0.95, n2);
    float veil = smoothstep(0.35, 0.95, fbm(q * 0.8 + float2(t * 0.18, t * 0.12) + 7.0));
    float3 col = base;
    col = mix(col, warm, glow * 0.42);
    col = mix(col, cool, veil * 0.30);
    float ribbon = 1.0 - smoothstep(0.0, 0.10, abs(p.y + 0.28 * sin(p.x * 1.4 + t * 1.6) - 0.05));
    col += accent * ribbon * 0.045;
    return col;
}

float3 wavesStyle(float2 p, float t, float3 base, float3 warm, float3 cool, float3 accent) {
    float drift = fbm(p * 1.1 + float2(t * 0.16, -t * 0.10));
    float3 col = mix(base, warm, drift * 0.22);
    float crest = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float y = p.y + fi * 0.085 - 0.18;
        float wave = sin(p.x * (1.1 + fi * 0.23) + t * (0.8 + fi * 0.2) + fi * 1.9) * 0.055;
        wave += (fbm(float2(p.x * 1.3 + fi * 2.0, t * 0.2)) - 0.5) * 0.09;
        crest += (1.0 - smoothstep(0.0, 0.018, abs(y - wave))) * (0.22 - fi * 0.03);
    }
    col = mix(col, cool, clamp(crest, 0.0, 1.0) * 0.5);
    col = mix(col, accent, smoothstep(0.55, 1.0, drift) * 0.12);
    return col;
}

float3 patternStyle(float2 p, float t, float3 base, float3 warm, float3 cool, float3 accent) {
    float angle = t * 0.06;
    float2 r = float2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
    float2 cell = fract(r * 3.0 + float2(t * 0.02, 0.0)) - 0.5;
    float d = length(cell);
    float ring = 1.0 - smoothstep(0.30, 0.33, d);
    float center = 1.0 - smoothstep(0.02, 0.05, d);
    float weave = sin((r.x + r.y) * 12.566 + fbm(r * 1.2 + t * 0.1) * 3.0) * 0.5 + 0.5;
    float3 col = mix(base, warm, (ring * 0.55 + center * 0.5) * 0.22 * (0.35 + 0.65 * weave));
    col = mix(col, cool, weave * 0.09);
    float lane = 1.0 - smoothstep(0.0, 0.012, abs(fract(r.x * 1.6 + r.y * 0.2) - 0.5));
    col = mix(col, accent, lane * 0.05);
    return col;
}

float3 bubblesStyle(float2 p, float t, float3 base, float3 warm, float3 cool, float3 accent) {
    float3 col = mix(base, warm, fbm(p * 1.2 + float2(t * 0.05, -t * 0.04)) * 0.14);
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        float rnd = hash21(float2(fi * 1.7, 4.2));
        float radius = 0.035 + 0.085 * rnd;
        float speed = 0.05 + 0.04 * rnd;
        float x = (hash21(float2(fi * 3.1, 9.4)) * 2.0 - 1.0) * 1.05;
        float y = fract(hash21(float2(fi * 5.3, 2.8)) + t * speed) * 2.6 - 1.3;
        float2 center = float2(x + 0.06 * sin(t * 1.2 + fi * 1.7), y);
        float d = length(p - center);
        float disc = 1.0 - smoothstep(radius * 0.92, radius, d);
        float rim = disc * smoothstep(radius * 0.55, radius * 0.98, d);
        float3 tint = mix(cool, accent, 0.5 + 0.5 * sin(fi * 1.3 + t * 0.6));
        col = mix(col, tint, rim * 0.5);
        float highlight = 1.0 - smoothstep(0.0, radius * 0.20, length(p - (center + float2(-radius * 0.35, radius * 0.42))));
        col += float3(0.9) * highlight * disc * 0.05;
    }
    return col;
}

float3 dunesStyle(float2 p, float t, float3 base, float3 warm, float3 cool, float3 accent) {
    float3 col = base;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float h = fbm(float2(p.x * 0.7 + fi * 2.7 + t * 0.06, fi * 1.3)) - 0.5;
        float curve = 0.32 * sin(p.x * (0.9 + fi * 0.2) + t * (0.18 + fi * 0.05) + fi * 1.6) + h * 0.55;
        float y = p.y - (fi * 0.30 - 0.45);
        float band = 1.0 - smoothstep(0.0, 0.16, abs(y - curve));
        col = mix(col, mix(warm, cool, fi / 3.0), band * 0.10);
    }
    col = mix(col, accent, smoothstep(0.4, 1.0, fbm(p * 0.9 + float2(t * 0.05, 0.0))) * 0.10);
    return col;
}

fragment float4 fs_main(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(0)]]) {
    float2 frag = in.position.xy;
    float2 resolution = max(uniforms.resolution, float2(1.0, 1.0));
    float2 p = (frag - resolution * 0.5) / resolution.y;
    float t = uniforms.params.x;
    float dark = uniforms.params2.x;
    float intensity = uniforms.params2.y;

    float3 base;
    float3 warm;
    float3 cool;
    float3 accent;

    if (dark > 0.5) {
        base = float3(0.047, 0.054, 0.066);
        warm = float3(0.470, 0.310, 0.207);
        cool = float3(0.157, 0.267, 0.247);
        accent = float3(0.639, 0.435, 0.286);
    } else {
        base = float3(0.961, 0.945, 0.922);
        warm = float3(0.851, 0.659, 0.529);
        cool = float3(0.659, 0.741, 0.694);
        accent = float3(0.918, 0.827, 0.753);
    }

    float3 themeBase = clamp(uniforms.baseTint.rgb, float3(0.0), float3(1.0));
    base = mix(base, themeBase, 0.55);

    float3 themeAccent = clamp(uniforms.accent.rgb, float3(0.0), float3(1.0));
    float accentWeight = dark > 0.5 ? 0.30 : 0.20;
    warm = mix(warm, themeAccent * (dark > 0.5 ? 0.8 : 0.9), accentWeight);

    int style = int(uniforms.params.y + 0.5);
    float3 col;
    if (style == 1) {
        col = wavesStyle(p, t, base, warm, cool, accent);
    } else if (style == 2) {
        col = patternStyle(p, t, base, warm, cool, accent);
    } else if (style == 3) {
        col = bubblesStyle(p, t, base, warm, cool, accent);
    } else if (style == 4) {
        col = dunesStyle(p, t, base, warm, cool, accent);
    } else {
        col = auroraStyle(p, t, base, warm, cool, accent);
    }

    col = mix(base, col, clamp(intensity, 0.0, 1.0));

    float vignette = 1.0 - smoothstep(0.25, 1.25, length(p * float2(0.85, 1.0)));
    col *= mix(1.0, vignette, 0.18);

    float grain = hash21(frag * 0.75 + fract(t) * 91.0) - 0.5;
    col += grain * 0.010;

    return float4(col, 1.0);
}
"""

/// A cheap, ambient Metal background. One pipeline is shared by every instance; each instance owns
/// only its drawable and display link. The view renders at 30 fps and stops as soon as it leaves the
/// window, is hidden, or the app goes to the background.
public final class SyncGramShaderView: UIView {
    private struct Uniforms {
        var resolution: SIMD2<Float>
        var params: SIMD2<Float>
        var params2: SIMD4<Float>
        var accent: SIMD4<Float>
        var baseTint: SIMD4<Float>
    }

    private struct Resources {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        let pipelineState: MTLRenderPipelineState
    }

    private enum Shared {
        static let resources: Resources? = {
            guard let device = MTLCreateSystemDefaultDevice() else {
                return nil
            }
            guard let library = try? device.makeLibrary(source: syncGramShaderSource, options: nil) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "vs_main"), let fragmentFunction = library.makeFunction(name: "fs_main"), let commandQueue = device.makeCommandQueue() else {
                return nil
            }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
                return nil
            }
            return Resources(device: device, commandQueue: commandQueue, pipelineState: pipelineState)
        }()
    }

    public var style: SyncGramShaderStyle

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var elapsed: Float = 0.0
    private var isPausedByHost = false
    private var isApplicationActive = true
    private var isDark = false
    private var accentColor = SIMD3<Float>(0.72, 0.52, 0.36)
    private var baseTint = SIMD3<Float>(0.05, 0.06, 0.07)
    private var fallbackLayer: CAGradientLayer?

    private var metalLayer: CAMetalLayer {
        return self.layer as! CAMetalLayer
    }

    public init(style: SyncGramShaderStyle) {
        self.style = style
        super.init(frame: .zero)

        self.isUserInteractionEnabled = false
        self.isOpaque = true
        self.backgroundColor = UIColor(red: 0.047, green: 0.054, blue: 0.066, alpha: 1.0)

        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = true
        self.metalLayer.isOpaque = true
        self.metalLayer.allowsNextDrawableTimeout = true

        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationStateChanged), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationStateChanged), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        self.displayLink?.invalidate()
    }

    public override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }

    public func update(isDark: Bool, accent: UIColor, base: UIColor) {
        self.isDark = isDark
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        if accent.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.accentColor = SIMD3<Float>(Float(red), Float(green), Float(blue))
        }
        if base.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.baseTint = SIMD3<Float>(Float(red), Float(green), Float(blue))
        }
        self.backgroundColor = isDark ? UIColor(red: 0.047, green: 0.054, blue: 0.066, alpha: 1.0) : UIColor(red: 0.961, green: 0.945, blue: 0.922, alpha: 1.0)
        self.fallbackLayer?.colors = self.fallbackColors(isDark: isDark)
    }

    public func setPaused(_ paused: Bool) {
        self.isPausedByHost = paused
        self.updateLinkState()
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        self.updateLinkState()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        let scale = self.traitCollection.displayScale
        let pixelSize = CGSize(width: max(1.0, self.bounds.width * scale), height: max(1.0, self.bounds.height * scale))
        if self.metalLayer.drawableSize != pixelSize {
            self.metalLayer.drawableSize = pixelSize
            self.metalLayer.contentsScale = scale
        }
        self.fallbackLayer?.frame = self.bounds
    }

    @objc private func applicationStateChanged() {
        self.isApplicationActive = UIApplication.shared.applicationState != .background
        self.updateLinkState()
    }

    private func updateLinkState() {
        let visible = self.window != nil && !self.isHidden && self.alpha > 0.01
        let shouldRun = visible && self.isApplicationActive && !self.isPausedByHost
        if shouldRun {
            if self.displayLink == nil {
                let link = CADisplayLink(target: self, selector: #selector(self.tick))
                link.preferredFramesPerSecond = 30
                link.add(to: .main, forMode: .common)
                self.displayLink = link
            }
            self.displayLink?.isPaused = false
        } else {
            self.displayLink?.isPaused = true
            if self.window == nil {
                self.displayLink?.invalidate()
                self.displayLink = nil
                self.lastTimestamp = 0.0
            }
        }
    }

    private func installFallbackIfNeeded() {
        guard Shared.resources == nil, self.fallbackLayer == nil else {
            return
        }
        let gradient = CAGradientLayer()
        gradient.frame = self.bounds
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradient.colors = self.fallbackColors(isDark: self.isDark)
        self.layer.insertSublayer(gradient, at: 0)
        self.fallbackLayer = gradient
    }

    private func fallbackColors(isDark: Bool) -> [CGColor] {
        if isDark {
            return [
                UIColor(red: 0.047, green: 0.054, blue: 0.066, alpha: 1.0).cgColor,
                UIColor(red: 0.145, green: 0.118, blue: 0.094, alpha: 1.0).cgColor,
                UIColor(red: 0.157, green: 0.200, blue: 0.180, alpha: 1.0).cgColor
            ]
        } else {
            return [
                UIColor(red: 0.961, green: 0.945, blue: 0.922, alpha: 1.0).cgColor,
                UIColor(red: 0.937, green: 0.898, blue: 0.851, alpha: 1.0).cgColor,
                UIColor(red: 0.890, green: 0.925, blue: 0.894, alpha: 1.0).cgColor
            ]
        }
    }

    @objc private func tick() {
        guard let resources = Shared.resources else {
            self.installFallbackIfNeeded()
            return
        }
        if self.metalLayer.device == nil {
            self.metalLayer.device = resources.device
        }
        let timestamp = CACurrentMediaTime()
        var delta: CFTimeInterval = 0.0
        if self.lastTimestamp > 0.0 {
            delta = timestamp - self.lastTimestamp
        }
        self.lastTimestamp = timestamp
        let speed: Float = UIAccessibility.isReduceMotionEnabled ? 0.25 : 1.0
        self.elapsed += Float(min(max(delta, 0.0), 0.1)) * speed
        self.render(resources: resources)
    }

    private func render(resources: Resources) {
        let size = self.metalLayer.drawableSize
        guard size.width > 0.0, size.height > 0.0, let drawable = self.metalLayer.nextDrawable() else {
            return
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        guard let commandBuffer = resources.commandQueue.makeCommandBuffer(), let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }

        var uniforms = Uniforms(
            resolution: SIMD2<Float>(Float(size.width), Float(size.height)),
            params: SIMD2<Float>(self.elapsed, Float(self.style.rawValue)),
            params2: SIMD4<Float>(self.isDark ? 1.0 : 0.0, 1.0, 0.0, 0.0),
            accent: SIMD4<Float>(self.accentColor.x, self.accentColor.y, self.accentColor.z, 1.0),
            baseTint: SIMD4<Float>(self.baseTint.x, self.baseTint.y, self.baseTint.z, 1.0)
        )

        encoder.setRenderPipelineState(resources.pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}