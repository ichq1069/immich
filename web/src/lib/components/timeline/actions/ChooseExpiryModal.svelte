<script lang="ts">
  import { Modal, ModalBody, ModalFooter, Button } from '@immich/ui';

  type ExpiryOption = { label: string; value: '1h' | '24h' | '7d' | 'permanent' };

  interface Props {
    onClose: (result?: { expiresIn: string }) => void;
  }

  let { onClose }: Props = $props();

  const options: ExpiryOption[] = [
    { label: '1 小时', value: '1h' },
    { label: '24 小时', value: '24h' },
    { label: '7 天', value: '7d' },
    { label: '永久', value: 'permanent' },
  ];

  let selected: ExpiryOption = $state(options[0]);
</script>

<Modal title="选择 R2 直链有效期" {onClose} size="small">
  <ModalBody>
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
  </ModalBody>
  <ModalFooter>
    <Button onclick={() => onClose()} color="secondary">取消</Button>
    <Button onclick={() => onClose({ expiresIn: selected.value })} color="primary">确认</Button>
  </ModalFooter>
</Modal>