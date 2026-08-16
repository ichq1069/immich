<script lang="ts">
  import { assetMultiSelectManager } from '$lib/managers/asset-multi-select-manager.svelte';
  import { createR2Links } from '$lib/services/r2-link.service';
  import { IconButton, modalManager, toastManager } from '@immich/ui';
  import { mdiLinkVariant } from '@mdi/js';
  import ChooseExpiryModal from './ChooseExpiryModal.svelte';

  interface Props {
    menuItem?: boolean;
  }

  let { menuItem = false }: Props = $props();

  const handleClick = async () => {
    const assets = assetMultiSelectManager.assets;
    if (assets.length === 0) return;

    const result = await modalManager.show<{ expiresIn: '1h' | '24h' | '7d' | 'permanent' }>(ChooseExpiryModal, {});
    if (!result) return;

    try {
      const links = await createR2Links({
        assetIds: assets.map((a) => a.id),
        expiresIn: result.expiresIn,
      });

      const text = links.map((l) => l.url).join('\n');
      await navigator.clipboard.writeText(text);
      toastManager.success({ message: `已生成 ${links.length} 个 R2 直链，已复制到剪贴板`, timeout: 3000 });
      assetMultiSelectManager.clear();
    } catch (e) {
      toastManager.error({ message: '生成 R2 直链失败', timeout: 3000 });
    }
  };
</script>

{#if menuItem}
  <button class="menu-item" onclick={handleClick}>
    <span class="icon">
      <svg viewBox="0 0 24 24"><path d={mdiLinkVariant} /></svg>
    </span>
    <span class="label">获取 R2 直链</span>
  </button>
{:else}
  <IconButton icon={mdiLinkVariant} title="获取 R2 直链" onclick={handleClick} />
{/if}