import { useId } from 'react';
import { Minus, Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface QuantityStepperProps {
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  size?: 'sm' | 'default';
  inputLabel?: string;
}

export function QuantityStepper({ 
  value, 
  onChange, 
  min = 1, 
  max = 999,
  size = 'default',
  inputLabel = 'تعداد',
}: QuantityStepperProps) {
  const inputId = useId();
  const decrease = () => {
    if (value > min) {
      onChange(value - 1);
    }
  };

  const increase = () => {
    if (value < max) {
      onChange(value + 1);
    }
  };

  const buttonSize = size === 'sm' ? 'h-8 w-8' : 'h-10 w-10';
  const inputSize = size === 'sm' ? 'h-8 w-12 text-sm' : 'h-10 w-16';
  const decreaseLabel = `کاهش ${inputLabel}`;
  const increaseLabel = `افزایش ${inputLabel}`;

  return (
    <div className="flex items-center gap-1">
      <label htmlFor={inputId} className="sr-only">
        {inputLabel}
      </label>
      <Button
        type="button"
        variant="outline"
        size="icon"
        className={buttonSize}
        onClick={decrease}
        disabled={value <= min}
        aria-label={decreaseLabel}
        title={decreaseLabel}
      >
        <Minus className="w-4 h-4" />
      </Button>
      
      <input
        id={inputId}
        type="number"
        value={value}
        onChange={(e) => {
          const val = parseInt(e.target.value) || min;
          onChange(Math.min(Math.max(val, min), max));
        }}
        className={`${inputSize} text-center border border-input rounded-lg bg-background focus:outline-none focus:ring-2 focus:ring-ring`}
        min={min}
        max={max}
        inputMode="numeric"
      />
      
      <Button
        type="button"
        variant="outline"
        size="icon"
        className={buttonSize}
        onClick={increase}
        disabled={value >= max}
        aria-label={increaseLabel}
        title={increaseLabel}
      >
        <Plus className="w-4 h-4" />
      </Button>
    </div>
  );
}
