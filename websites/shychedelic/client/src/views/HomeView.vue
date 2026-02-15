<script setup lang="ts">
import HeroSection from '@/components/layout/HeroSection.vue'
import FeatureCard from '@/components/ui/FeatureCard.vue'
import SectionDivider from '@/components/ui/SectionDivider.vue'
import AppButton from '@/components/ui/AppButton.vue'
</script>

<template>
  <div class="page">
    <HeroSection tagline="Community Hub" />

    <section class="features-section">
      <div class="features-intro">
      </div>

      <div class="features-container">
        <FeatureCard
          title="Matrix Chat"
          description="Decentralized, encrypted messaging on our self-hosted server. Discord went full enshittification mode, so here we are. No tracking, no ads, no IDs — just hangin with the homies."
          featured
          :requires-auth="true"
          status="online"
        >
          <template #icon>
            <svg viewBox="0 0 24 24">
              <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2v10z"/>
            </svg>
          </template>
          <template #action>
            <AppButton to="/matrix">Join chat</AppButton>
          </template>
        </FeatureCard>

        <SectionDivider label="Coming Soon" />

        <div class="features-grid">
          <FeatureCard
            title="Game Servers"
            status="coming-soon"
            status-text="In development"
            :requires-auth="true"
          >
            <template #icon>
              <svg viewBox="0 0 24 24">
                <rect x="2" y="6" width="20" height="12" rx="2"/>
                <path d="M6 12h.01M10 12h.01"/>
                <path d="M14 10v4M18 10v4"/>
              </svg>
            </template>
          </FeatureCard>

          <FeatureCard
            title="Status Page"
            status="coming-soon"
            status-text="In development"
            :requires-auth="true"
          >
            <template #icon>
              <svg viewBox="0 0 24 24">
                <path d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                <path d="M9 12l2 2 4-4"/>
              </svg>
            </template>
          </FeatureCard>

          <FeatureCard
            title="Media Server"
            status="coming-soon"
            status-text="Planned"
            :requires-auth="true"
          >
            <template #icon>
              <svg viewBox="0 0 24 24">
                <polygon points="5,3 19,12 5,21 5,3"/>
              </svg>
            </template>
          </FeatureCard>

          <FeatureCard
            title="File Sharing"
            status="coming-soon"
            status-text="Planned"
            :requires-auth="true"
          >
            <template #icon>
              <svg viewBox="0 0 24 24">
                <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
                <polyline points="17,8 12,3 7,8"/>
                <line x1="12" y1="3" x2="12" y2="15"/>
              </svg>
            </template>
          </FeatureCard>
        </div>
      </div>
    </section>

  </div>
</template>

<style scoped>
.features-section {
  padding: 0 2rem 1.5rem;
}

.features-intro {
  max-width: 680px;
  margin: 0 auto 1.25rem;
  text-align: center;
}

.features-subtext {
  font-size: 0.9rem;
  color: var(--text-secondary);
  line-height: 1.5;
}

.features-container {
  max-width: 680px;
  margin: 0 auto;
}

.features-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1.25rem;
}

@media (max-width: 640px) {
  .features-section {
    padding: 0 1.5rem 2rem;
  }

  .features-grid {
    grid-template-columns: 1fr;
  }
}
</style>
