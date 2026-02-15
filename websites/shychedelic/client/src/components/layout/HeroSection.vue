<script setup lang="ts">
import LogoIcon from '@/assets/icons/logo.svg'

const props = withDefaults(defineProps<{
  title?: string
  tagline?: string
  icon?: string
  iconInvert?: boolean
}>(), {
  title: 'Shychedelic',
  iconInvert: false
})
</script>

<template>
  <section class="hero">
    <div class="logo-mark">
      <img :src="props.icon || LogoIcon" :alt="title" class="logo-img" :class="{ 'logo-img--invert': iconInvert }" />
    </div>
    <h1 class="title">{{ title }}</h1>
    <p v-if="tagline" class="tagline">{{ tagline }}</p>
  </section>
</template>

<style scoped>
.hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem 2rem 1.5rem;
  text-align: center;
}

.logo-mark {
  width: 88px;
  height: 88px;
  margin-bottom: 1.25rem;
  position: relative;
}

.logo-mark::before {
  content: '';
  position: absolute;
  inset: -20px;
  background: radial-gradient(circle, var(--purple-deep) 0%, transparent 70%);
  opacity: 0.4;
  filter: blur(20px);
  animation: pulse-glow 4s ease-in-out infinite;
}

.logo-mark .logo-img {
  width: 100%;
  height: 100%;
  position: relative;
  z-index: 1;
}

.logo-mark .logo-img--invert {
  filter: brightness(0) invert(1);
}

.title {
  font-size: clamp(2rem, 6vw, 3rem);
  font-weight: 700;
  letter-spacing: -0.02em;
  margin-bottom: 0.25rem;
  background: linear-gradient(135deg, var(--text-primary) 0%, var(--purple-bright) 50%, var(--cyan) 100%);
  background-size: 200% 200%;
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  animation: gradient-shift 8s ease infinite;
}

.tagline {
  font-family: 'Sora', sans-serif;
  font-size: 0.85rem;
  font-weight: 300;
  color: var(--text-secondary);
  letter-spacing: 0.2em;
  text-transform: uppercase;
}

@media (max-width: 640px) {
  .hero {
    padding: 3rem 1.5rem;
  }
}
</style>
