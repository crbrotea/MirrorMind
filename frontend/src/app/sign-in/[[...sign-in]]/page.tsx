import { SignIn } from '@clerk/nextjs';

export default function SignInPage() {
  return (
    <main className="flex min-h-dvh items-center justify-center bg-[#0a0a1a]">
      <SignIn />
    </main>
  );
}
