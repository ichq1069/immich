<script lang="ts">
  import { onMount } from 'svelte';
  import UserPageLayout from '$lib/components/layouts/UserPageLayout.svelte';
  import { getR2Links, revokeR2Link, type R2LinkResponse } from '$lib/services/r2-link.service';
  import { toastManager, Container } from '@immich/ui';
  import { t } from 'svelte-i18n';

  let links: R2LinkResponse[] = $state([]);
  let loading = $state(true);

  const loadLinks = async () => {
    try {
      links = await getR2Links();
    } catch {
      toastManager.error({ message: '加载 R2 直链列表失败', timeout: 3000 });
    } finally {
      loading = false;
    }
  };

  onMount(loadLinks);

  const handleRevoke = async (id: string) => {
    try {
      await revokeR2Link(id);
      links = links.filter((l) => l.id !== id);
      toastManager.success({ message: '已撤销', timeout: 2000 });
    } catch {
      toastManager.error({ message: '撤销失败', timeout: 3000 });
    }
  };

  const handleCopy = async (url: string) => {
    try {
      await navigator.clipboard.writeText(url);
      toastManager.success({ message: '已复制', timeout: 2000 });
    } catch {
      toastManager.error({ message: '复制失败', timeout: 2000 });
    }
  };

  const formatExpiry = (expiresAt: string | null) => {
    if (!expiresAt) return '永久';
    return new Date(expiresAt).toLocaleString();
  };

  const isExpired = (expiresAt: string | null) => {
    if (!expiresAt) return false;
    return new Date(expiresAt) < new Date();
  };
</script>

<UserPageLayout>
  <Container>
    <h1 class="text-2xl font-bold mb-6">R2 直链管理</h1>

    {#if loading}
      <p class="text-dim">加载中...</p>
    {:else if links.length === 0}
      <p class="text-dim">暂无 R2 直链</p>
    {:else}
      <div class="flex flex-col gap-3">
        {#each links as link}
          <div class="flex items-center gap-3 p-4 border rounded-lg">
            <div class="flex-1 min-w-0">
              <div class="text-sm truncate">{link.url}</div>
              <div class="text-xs text-dim mt-1">
                创建: {new Date(link.createdAt).toLocaleString()}
                &middot; 过期: {formatExpiry(link.expiresAt)}
                {#if isExpired(link.expiresAt)}
                  <span class="text-red-500 ml-1">(已过期)</span>
                {/if}
              </div>
            </div>
            <button class="px-3 py-1 text-sm rounded border" onclick={() => handleCopy(link.url)}>复制</button>
            <button class="px-3 py-1 text-sm rounded border text-red-500" onclick={() => handleRevoke(link.id)}>撤销</button>
          </div>
        {/each}
      </div>
    {/if}
  </Container>
</UserPageLayout>