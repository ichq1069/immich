<script lang="ts">
  import { ModalBase } from '@immich/ui';

  type ExpiryOption = { label: string; value: '1h' | '24h' | '7d' | 'permanent' };

  const options: ExpiryOption[] = [
    { label: '1 小时', value: '1h' },
    { label: '24 小时', value: '24h' },
    { label: '7 天', value: '7d' },
    { label: '永久', value: 'permanent' },
  ];

  let selected: ExpiryOption = options[0];

  const handleConfirm = () => {
    ModalBase.dispatch({ expiresIn: selected.value });
  };
</script>

<ModalBase title="选择 R2 直链有效期">
  <div class="flex flex-col gap-3 p-4">
    {#each options as option}
      <label class="flex items-center gap-2 cursor-pointer">
        <input
          type="radio"
          name="expiry"
          value={option.value}
          checked={selected.value === option.value}
          onchange={() => (selected = option)}
        />
        <span>{option.label}</span>
      </label>
    {/each}
  </div>
  <div class="flex justify-end gap-2 p-4 border-t">
    <button class="px-4 py-2 rounded" onclick={() => ModalBase.dispatch(undefined)}>取消</button>
    <button class="px-4 py-2 rounded bg-primary text-white" onclick={handleConfirm}>确认</button>
  </div>
</ModalBase>