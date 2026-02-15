<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'

interface Particle {
  x: number
  y: number
  vx: number
  vy: number
  baseVy: number
  wanderAngle: number
  wanderSpeed: number
  size: number
  opacity: number
  maxOpacity: number
  hue: number
  isCyan: boolean
  orbitDirection: number
  orbitRadius: number
}

interface Orb {
  x: number
  y: number
  vx: number
  vy: number
  size: number
  color: string
}

const canvasRef = ref<HTMLCanvasElement | null>(null)
let ctx: CanvasRenderingContext2D | null = null
const orbs = ref<Orb[]>([])
const particles: Particle[] = []
const particleCount = 50

const mouse = { x: 0, y: 0, active: false, down: false }
const GRAVITY_RADIUS = 250
const GRAVITY_RADIUS_HOLD = 400
let hoverDisabledUntil = 0

let animationId: number
let isDestroyed = false

function initOrbs() {
  const quadrants = [
    { x: 20, y: 20 },
    { x: 70, y: 20 },
    { x: 20, y: 70 },
    { x: 70, y: 70 },
  ]

  const shuffled = quadrants.sort(() => Math.random() - 0.5)

  const configs = [
    { size: 900, color: 'rgba(124, 58, 237, 0.15)' },
    { size: 800, color: 'rgba(6, 182, 212, 0.12)' },
    { size: 750, color: 'rgba(168, 85, 247, 0.1)' },
    { size: 650, color: 'rgba(6, 182, 212, 0.08)' },
  ]

  orbs.value = configs.map((config, i) => {
    const start = shuffled[i]
    return {
      x: start.x + (Math.random() - 0.5) * 20,
      y: start.y + (Math.random() - 0.5) * 20,
      vx: (Math.random() - 0.5) * 0.02,
      vy: (Math.random() - 0.5) * 0.02,
      size: config.size,
      color: config.color,
    }
  })
}

function createParticle(): Particle {
  const isCyan = Math.random() > 0.5
  const baseVy = -(0.3 + Math.random() * 0.4)
  const size = 1 + Math.random() * 1.5
  return {
    x: Math.random() * window.innerWidth,
    y: window.innerHeight + 20,
    vx: 0,
    vy: baseVy,
    baseVy,
    wanderAngle: Math.random() * Math.PI * 2,
    wanderSpeed: 0.02 + Math.random() * 0.03,
    size,
    opacity: 0,
    maxOpacity: 0.25 + Math.random() * 0.25,
    hue: isCyan ? 186 : 270,
    isCyan,
    orbitDirection: Math.random() > 0.5 ? 1 : -1,
    orbitRadius: 30 + Math.random() * 80,
  }
}

function initParticles() {
  for (let i = 0; i < particleCount; i++) {
    const p = createParticle()
    p.y = Math.random() * window.innerHeight
    p.opacity = p.maxOpacity * (0.3 + Math.random() * 0.7)
    particles.push(p)
  }
}

function updateParticles() {
  for (let i = 0; i < particles.length; i++) {
    const p = particles[i]

    const dx = mouse.x - p.x
    const dy = mouse.y - p.y
    const dist = Math.sqrt(dx * dx + dy * dy)

    if (mouse.active && mouse.down && dist < GRAVITY_RADIUS_HOLD) {
      const influence = Math.pow(1 - dist / GRAVITY_RADIUS_HOLD, 2)

      const pullStrength = influence * 0.15
      p.vx += (dx / dist) * pullStrength
      p.vy += (dy / dist) * pullStrength

      if (dist < p.orbitRadius * 2) {
        const orbitInfluence = Math.pow(1 - dist / (p.orbitRadius * 2), 1.5)
        const sizeMultiplier = (2.5 - p.size) / 1.5
        const radiusMultiplier = 60 / p.orbitRadius
        const orbitSpeed = (0.02 + orbitInfluence * 0.08) * sizeMultiplier * radiusMultiplier
        const perpX = -dy / dist
        const perpY = dx / dist
        p.vx += perpX * orbitSpeed * p.orbitDirection
        p.vy += perpY * orbitSpeed * p.orbitDirection
      }

      const maxSpeed = 2 + influence * 3
      const speed = Math.sqrt(p.vx * p.vx + p.vy * p.vy)
      if (speed > maxSpeed) {
        p.vx = (p.vx / speed) * maxSpeed
        p.vy = (p.vy / speed) * maxSpeed
      }

      p.vx *= 0.98
      p.vy *= 0.98

    } else if (mouse.active && !mouse.down && dist < GRAVITY_RADIUS && Date.now() > hoverDisabledUntil) {
      const influence = Math.pow(1 - dist / GRAVITY_RADIUS, 2)
      const pullStrength = influence * 0.02
      p.vx += (dx / dist) * pullStrength
      p.vy += (dy / dist) * pullStrength

      p.wanderAngle += (Math.random() - 0.5) * 0.3
      p.vx += Math.cos(p.wanderAngle) * p.wanderSpeed * 0.1
      p.vx *= 0.98
      p.vy += (p.baseVy - p.vy) * 0.015

    } else {
      p.wanderAngle += (Math.random() - 0.5) * 0.3
      p.vx += Math.cos(p.wanderAngle) * p.wanderSpeed * 0.1
      p.vx *= 0.96
      p.vy += (p.baseVy - p.vy) * 0.008
    }

    p.x += p.vx
    p.y += p.vy

    const isCaptured = mouse.active && mouse.down && dist < GRAVITY_RADIUS_HOLD

    if (isCaptured) {
      p.opacity = Math.min(p.maxOpacity, p.opacity + 0.02)
    } else if (p.y > window.innerHeight * 0.9) {
      p.opacity = Math.min(p.maxOpacity, p.opacity + 0.02)
    } else if (p.y < 0) {
      p.opacity = Math.max(0, p.opacity - 0.03)
    }

    if (!isCaptured && (p.y < -50 || p.opacity <= 0)) {
      const newP = createParticle()
      particles[i] = newP
    }
  }
}

function drawCursorGlow() {
  if (!ctx || !mouse.active || !mouse.down) return

  let orbitingCount = 0
  for (const p of particles) {
    const dx = mouse.x - p.x
    const dy = mouse.y - p.y
    const dist = Math.sqrt(dx * dx + dy * dy)
    if (dist < p.orbitRadius * 2) {
      orbitingCount++
    }
  }

  if (orbitingCount === 0) return

  const intensity = Math.min(orbitingCount / 15, 1)
  const glowRadius = 40 + intensity * 60

  const gradient = ctx.createRadialGradient(mouse.x, mouse.y, 0, mouse.x, mouse.y, glowRadius)
  gradient.addColorStop(0, `rgba(168, 85, 247, ${0.15 * intensity})`)
  gradient.addColorStop(0.4, `rgba(124, 58, 237, ${0.08 * intensity})`)
  gradient.addColorStop(0.7, `rgba(6, 182, 212, ${0.04 * intensity})`)
  gradient.addColorStop(1, 'rgba(0, 0, 0, 0)')

  ctx.fillStyle = gradient
  ctx.beginPath()
  ctx.arc(mouse.x, mouse.y, glowRadius, 0, Math.PI * 2)
  ctx.fill()
}

function drawParticles() {
  if (!ctx) return

  for (const p of particles) {
    if (p.opacity <= 0) continue

    ctx.save()

    const glowSize = p.size * 6
    const gradient = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, glowSize)
    gradient.addColorStop(0, `hsla(${p.hue}, 85%, 70%, ${p.opacity})`)
    gradient.addColorStop(0.2, `hsla(${p.hue}, 80%, 60%, ${p.opacity * 0.5})`)
    gradient.addColorStop(0.5, `hsla(${p.hue}, 80%, 55%, ${p.opacity * 0.2})`)
    gradient.addColorStop(1, `hsla(${p.hue}, 80%, 50%, 0)`)

    ctx.fillStyle = gradient
    ctx.beginPath()
    ctx.arc(p.x, p.y, glowSize, 0, Math.PI * 2)
    ctx.fill()

    ctx.fillStyle = `hsla(${p.hue}, 90%, 80%, ${p.opacity})`
    ctx.beginPath()
    ctx.arc(p.x, p.y, p.size * 0.6, 0, Math.PI * 2)
    ctx.fill()

    ctx.restore()
  }
}

function updateOrbs() {
  const repulsionStrength = 0.00015
  const centerPull = 0.00001
  const friction = 0.995
  const maxSpeed = 0.03

  for (let i = 0; i < orbs.value.length; i++) {
    const orb = orbs.value[i]

    for (let j = 0; j < orbs.value.length; j++) {
      if (i === j) continue
      const other = orbs.value[j]

      const dx = orb.x - other.x
      const dy = orb.y - other.y
      const dist = Math.sqrt(dx * dx + dy * dy)

      const minDist = (orb.size + other.size) / 25
      if (dist > 0 && dist < minDist) {
        const overlap = 1 - dist / minDist
        const force = repulsionStrength * overlap * overlap * 1000
        orb.vx += (dx / dist) * force
        orb.vy += (dy / dist) * force
      }
    }

    orb.vx += (50 - orb.x) * centerPull
    orb.vy += (50 - orb.y) * centerPull

    orb.vx += (Math.random() - 0.5) * 0.001
    orb.vy += (Math.random() - 0.5) * 0.001

    orb.vx *= friction
    orb.vy *= friction

    const speed = Math.sqrt(orb.vx * orb.vx + orb.vy * orb.vy)
    if (speed > maxSpeed) {
      orb.vx = (orb.vx / speed) * maxSpeed
      orb.vy = (orb.vy / speed) * maxSpeed
    }

    orb.x += orb.vx
    orb.y += orb.vy

    if (orb.x < -15) { orb.x = -15; orb.vx *= -0.5 }
    if (orb.x > 105) { orb.x = 105; orb.vx *= -0.5 }
    if (orb.y < -15) { orb.y = -15; orb.vy *= -0.5 }
    if (orb.y > 105) { orb.y = 105; orb.vy *= -0.5 }
  }
}

function resize() {
  if (!canvasRef.value) return

  const dpr = window.devicePixelRatio || 1
  canvasRef.value.width = window.innerWidth * dpr
  canvasRef.value.height = window.innerHeight * dpr
  canvasRef.value.style.width = `${window.innerWidth}px`
  canvasRef.value.style.height = `${window.innerHeight}px`

  ctx = canvasRef.value.getContext('2d', { alpha: true })
  if (ctx) {
    ctx.scale(dpr, dpr)
  }
}

function animate() {
  if (isDestroyed) return

  if (ctx) {
    ctx.clearRect(0, 0, window.innerWidth, window.innerHeight)
  }

  updateOrbs()
  updateParticles()
  drawCursorGlow()
  drawParticles()

  animationId = requestAnimationFrame(animate)
}

function isOverUIElement(target: EventTarget | null): boolean {
  if (!target || !(target instanceof Element)) return false
  return !!target.closest('.app-header, .glass-card, button, a, input, [data-no-particle-interact]')
}

function handleMouseMove(e: MouseEvent) {
  mouse.x = e.clientX
  mouse.y = e.clientY
  mouse.active = !isOverUIElement(e.target)
}

function handleMouseLeave() {
  mouse.active = false
  mouse.down = false
  document.body.style.userSelect = ''
}

function handleTouchMove(e: TouchEvent) {
  if (e.touches.length > 0) {
    const touch = e.touches[0]
    mouse.x = touch.clientX
    mouse.y = touch.clientY
    const elementAtTouch = document.elementFromPoint(touch.clientX, touch.clientY)
    mouse.active = !isOverUIElement(elementAtTouch)
  }
}

function handleTouchEnd() {
  mouse.active = false
  mouse.down = false
  document.body.style.userSelect = ''
  hoverDisabledUntil = Date.now() + 1600
}

function handleMouseDown(e: MouseEvent) {
  if (isOverUIElement(e.target)) return
  mouse.down = true
  document.body.style.userSelect = 'none'
}

function handleMouseUp() {
  mouse.down = false
  document.body.style.userSelect = ''
  hoverDisabledUntil = Date.now() + 1600
}

function handleTouchStart(e: TouchEvent) {
  if (e.touches.length > 0) {
    const touch = e.touches[0]
    const elementAtTouch = document.elementFromPoint(touch.clientX, touch.clientY)
    if (isOverUIElement(elementAtTouch)) return
    mouse.x = touch.clientX
    mouse.y = touch.clientY
    mouse.active = true
    mouse.down = true
    document.body.style.userSelect = 'none'
  }
}

onMounted(() => {
  resize()
  initOrbs()
  initParticles()

  window.addEventListener('resize', resize)
  window.addEventListener('mousemove', handleMouseMove)
  window.addEventListener('mouseleave', handleMouseLeave)
  window.addEventListener('mousedown', handleMouseDown)
  window.addEventListener('mouseup', handleMouseUp)
  window.addEventListener('touchstart', handleTouchStart, { passive: true })
  window.addEventListener('touchmove', handleTouchMove, { passive: true })
  window.addEventListener('touchend', handleTouchEnd)
  animationId = requestAnimationFrame(animate)
})

onUnmounted(() => {
  isDestroyed = true
  cancelAnimationFrame(animationId)
  window.removeEventListener('resize', resize)
  window.removeEventListener('mousemove', handleMouseMove)
  window.removeEventListener('mouseleave', handleMouseLeave)
  window.removeEventListener('mousedown', handleMouseDown)
  window.removeEventListener('mouseup', handleMouseUp)
  window.removeEventListener('touchstart', handleTouchStart)
  window.removeEventListener('touchmove', handleTouchMove)
  window.removeEventListener('touchend', handleTouchEnd)
})
</script>

<template>
  <div class="bg-canvas">
    <div class="bg-gradient" />
    <div class="bg-orbs">
      <div
        v-for="(orb, index) in orbs"
        :key="index"
        class="orb"
        :style="{
          left: `${orb.x}%`,
          top: `${orb.y}%`,
          width: `${orb.size}px`,
          height: `${orb.size}px`,
          background: `radial-gradient(circle, ${orb.color} 0%, transparent 70%)`
        }"
      />
    </div>
    <canvas ref="canvasRef" class="particle-canvas" />
    <div class="noise" />
  </div>
</template>

<style scoped>
.bg-canvas {
  position: fixed;
  inset: 0;
  z-index: 0;
  overflow: hidden;
}

.bg-gradient {
  position: absolute;
  inset: -10%;
  width: 120%;
  height: 120%;
}

.bg-gradient::before,
.bg-gradient::after {
  content: '';
  position: absolute;
  inset: 0;
}

.bg-gradient::before {
  background:
    radial-gradient(ellipse 100% 70% at 15% 25%, rgba(124, 58, 237, 0.25) 0%, transparent 40%),
    radial-gradient(ellipse 80% 50% at 75% 85%, rgba(168, 85, 247, 0.2) 0%, transparent 40%);
  animation: gradient-drift-1 25s ease-in-out infinite;
}

.bg-gradient::after {
  background:
    radial-gradient(ellipse 90% 55% at 85% 30%, rgba(6, 182, 212, 0.18) 0%, transparent 45%),
    radial-gradient(ellipse 85% 65% at 25% 85%, rgba(6, 182, 212, 0.12) 0%, transparent 50%);
  animation: gradient-drift-2 30s ease-in-out infinite;
}

@keyframes gradient-drift-1 {
  0%, 100% {
    transform: translate(0, 0);
  }
  33% {
    transform: translate(3%, 5%);
  }
  66% {
    transform: translate(-2%, 3%);
  }
}

@keyframes gradient-drift-2 {
  0%, 100% {
    transform: translate(0, 0);
  }
  50% {
    transform: translate(-4%, -3%);
  }
}

.bg-orbs {
  position: absolute;
  inset: 0;
  overflow: hidden;
}

.orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  will-change: left, top;
}

.particle-canvas {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.noise {
  position: absolute;
  inset: 0;
  pointer-events: none;
  opacity: 0.018;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 512 512' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
  background-repeat: repeat;
  background-size: 256px 256px;
}
</style>
