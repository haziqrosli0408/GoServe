import { useState, useEffect, useMemo } from 'react';
import { auth, db } from './lib/firebase';
import { signInWithEmailAndPassword, onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { getFunctions, httpsCallable } from 'firebase/functions';
import {
  collection,
  query,
  onSnapshot,
  doc,
  updateDoc,
  orderBy,
  writeBatch,
  addDoc,
  where,
  getDocs,
} from 'firebase/firestore';
import {
  Users,
  Star,
  Briefcase,
  LogOut,
  Calendar,
  TrendingUp,
  ShieldCheck,
  X,
  Search,
  Check,
  Ban,
  Trash2,
  Download,
  Eye,
  EyeOff,
  UserCheck,
  MoreVertical,
  ChevronLeft,
  ChevronRight,
  RotateCcw,
  FileText,
  MapPin,
  Phone,
  Mail,
  ArrowLeft,
  DollarSign,
  Clock,
  LayoutGrid,
  List,
  CreditCard,
  Wallet, ShoppingBag, TrendingDown, RefreshCcw,
} from 'lucide-react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
} from 'recharts';

// --- PDF COMPONENT ---


// --- TYPES ---
interface AppUser {
  id: string;
  customId?: string;
  name: string;
  email: string;
  role: 'Seeker' | 'Professional' | 'customer' | 'provider';
  status: 'Active' | 'Suspended';
  profileUrl?: string;
  createdAt?: any;
  verificationStatus?: 'verified' | 'pending' | 'rejected' | string;
}

interface Review {
  id: string;
  customerName: string;
  providerName: string;
  serviceName: string;
  rating: number;
  comment: string;
  status: 'Pending' | 'Approved' | 'Rejected';
  createdAt?: any;
}

interface Service {
  id: string;
  title: string;
  providerName: string;
  providerId: string;
  price: string | number;
  isActive: boolean;
  category: string;
  subcategory?: string;
  description?: string;
  servicePhotoUrl?: string;
  details?: string[];
  addOns?: { name: string; price: string | number }[];
  galleryUrls?: string[];
  customId?: string;
}

interface Booking {
  id: string;
  orderId: string;
  customerId: string;
  providerId: string;
  providerName: string;
  serviceName: string;
  serviceId: string;
  category: string;
  serviceImage?: string;
  date: string;
  time: string;
  address: string;
  totalPrice: number;
  basePrice: number;
  chargeFee: number;
  paymentMethod: string;
  status: 'Pending' | 'Confirmed' | 'In Progress' | 'Completed' | 'Cancelled';
  createdAt: any;
  selectedAddOns?: { name: string; price: string | number }[];
}

interface Report {
  id: string;
  orderId: string;
  bookingId: string;
  serviceName: string;
  customerId: string;
  customerCustomId?: string;
  customerName: string;
  customerProfileUrl?: string;
  providerId: string;
  providerCustomId?: string;
  providerName: string;
  issue: string;
  status: 'pending' | 'resolved';
  timestamp: any;
}

interface VerificationRequest {
  id: string;
  name: string;
  email: string;
  selfieUrl: string;
  icFrontUrl?: string;
  icBackUrl?: string;
  icUrl?: string; // Legacy field
  address?: string;
}

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const [seekers, setSeekers] = useState<AppUser[]>([]);
  const [providers, setProviders] = useState<AppUser[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [verifications, setVerifications] = useState<VerificationRequest[]>([]);
  const [reports, setReports] = useState<Report[]>([]);
  const [profileDropdownOpen, setProfileDropdownOpen] = useState(false);
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false);
  const [sidebarSearch, setSidebarSearch] = useState('');

  const navigation = [
    { 
      group: 'Main', 
      items: [
        { id: 'dashboard', label: 'Dashboard', icon: <LayoutGrid size={18} /> },
        { id: 'users', label: 'Users', icon: <Users size={18} /> },
        { id: 'verification', label: 'Verification', icon: <UserCheck size={18} /> },
        { id: 'services', label: 'Services', icon: <Briefcase size={18} /> },
      ]
    },
    { 
      group: 'Activity', 
      items: [
        { id: 'bookings', label: 'Bookings', icon: <Calendar size={18} /> },
        { id: 'payments', label: 'Payments', icon: <CreditCard size={18} /> },
        { id: 'reviews', label: 'Reviews', icon: <Star size={18} /> },
        { id: 'reports', label: 'Reports', icon: <FileText size={18} /> },
      ]
    }
  ];

  const filteredNavigation = navigation.map(group => ({
    ...group,
    items: group.items.filter(item => 
      item.label.toLowerCase().includes(sidebarSearch.toLowerCase())
    )
  })).filter(group => group.items.length > 0);

  const users = useMemo(() => {
    const userMap = new Map<string, AppUser>();
    
    // Add seekers first (base data)
    seekers.forEach(s => userMap.set(s.id, { ...s }));
    
    // Add providers, merging only if it's a valid provider record
    providers.forEach(p => {
      const existing = userMap.get(p.id);
      
      // If they are in both, only upgrade to 'provider' if the provider record is substantial
      // or if they don't exist in the users collection yet.
      const isActuallyProvider = p.customId || !existing;
      
      userMap.set(p.id, {
        ...existing,
        ...p,
        role: isActuallyProvider ? (p.role || 'provider') : (existing?.role || 'customer')
      });
    });
    
    return Array.from(userMap.values());
  }, [seekers, providers]);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (u) => {
      setUser(u);
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  // Real-time listeners for all collections
  useEffect(() => {
    if (!user) return;

    const uUnsub = onSnapshot(collection(db, 'users'), (s) => setSeekers(s.docs.map(d => {
      const data = d.data();
      return { id: d.id, ...data, role: data.role || 'customer' } as any;
    })));
    const pUnsub = onSnapshot(collection(db, 'providers'), (s) => setProviders(s.docs.map(d => {
      const data = d.data();
      return { id: d.id, ...data, role: data.role || 'provider' } as any;
    })));
    const sUnsub = onSnapshot(collection(db, 'services'), (s) => setServices(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));
    const rUnsub = onSnapshot(collection(db, 'reviews'), (s) => setReviews(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));
    const bUnsub = onSnapshot(collection(db, 'bookings'), (s) => setBookings(s.docs.map(d => ({ id: d.id, ...d.data() } as any))));
    const vUnsub = onSnapshot(query(collection(db, 'providers'), orderBy('name')), (s) => {
      setVerifications(s.docs
        .filter(d => d.data().verificationStatus === 'pending')
        .map(d => ({ id: d.id, ...d.data() } as any))
      );
    });
    const rptsUnsub = onSnapshot(query(collection(db, 'reports'), orderBy('timestamp', 'desc')), (s) => {
      setReports(s.docs.map(d => ({ id: d.id, ...d.data() } as any)));
    });

    return () => { uUnsub(); pUnsub(); sUnsub(); rUnsub(); bUnsub(); vUnsub(); rptsUnsub(); };
  }, [user]);

  if (loading) return (
    <div className="h-screen w-screen flex items-center justify-center bg-gray-50">
      <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-orange-500"></div>
    </div>
  );

  if (!user) return <LoginPage />;

  return (
    <div className="flex h-screen bg-[#f8fafc] overflow-hidden text-slate-900 font-sans">
      {/* --- SIDEBAR --- */}
      <aside className={`${sidebarOpen ? 'w-64' : 'w-20'} bg-[#1a1c23] text-slate-400 transition-all duration-300 flex flex-col z-20 shadow-2xl`}>
        {/* Brand/Dropdown Area */}
        <div className="p-4 shrink-0">
          <div className="flex items-center justify-between p-3 bg-white/5 rounded-xl border border-white/10 hover:bg-white/10 cursor-pointer transition-colors group">
            <div className="flex items-center gap-3 min-w-0">
              <div className="w-8 h-8 bg-gradient-to-br from-orange-500 to-orange-600 rounded-lg flex items-center justify-center shrink-0 shadow-lg shadow-orange-500/20">
                <ShieldCheck size={18} className="text-white" />
              </div>
              {sidebarOpen && (
                <div className="min-w-0">
                  <h1 className="font-bold text-sm text-white truncate">GoServe</h1>
                  <p className="text-[10px] text-slate-500 truncate font-medium">Admin Panel</p>
                </div>
              )}
            </div>
            {sidebarOpen && <ChevronRight size={14} className="text-slate-600 rotate-90 group-hover:text-slate-400 transition-colors" />}
          </div>
        </div>

        {/* Sidebar Search */}
        {sidebarOpen && (
          <div className="px-4 mb-4">
            <div className="relative group">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-600 group-focus-within:text-orange-500 transition-colors" size={14} />
              <input 
                type="text" 
                placeholder="Search tabs ..." 
                value={sidebarSearch}
                onChange={(e) => setSidebarSearch(e.target.value)}
                className="w-full bg-white/5 border border-white/5 rounded-lg py-2 pl-9 pr-3 text-xs focus:outline-none focus:border-orange-500/50 focus:bg-white/10 transition-all placeholder:text-slate-600"
              />
              {sidebarSearch && (
                <button 
                  onClick={() => setSidebarSearch('')}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-600 hover:text-white"
                >
                  <X size={12} />
                </button>
              )}
            </div>
          </div>
        )}

        {/* Navigation */}
        <div className="flex-1 px-4 py-2 overflow-y-auto space-y-6 custom-scrollbar">
          {filteredNavigation.length > 0 ? (
            filteredNavigation.map((group) => (
              <div key={group.group}>
                {sidebarOpen && <p className="px-3 mb-3 text-[10px] font-bold text-slate-600 uppercase tracking-widest">{group.group}</p>}
                <nav className="space-y-1">
                  {group.items.map((item) => (
                    <NavItem 
                      key={item.id}
                      icon={item.icon} 
                      label={item.label} 
                      active={activeTab === item.id} 
                      collapsed={!sidebarOpen} 
                      onClick={() => setActiveTab(item.id)} 
                    />
                  ))}
                </nav>
              </div>
            ))
          ) : (
            sidebarOpen && (
              <div className="px-3 py-10 text-center">
                <Search size={24} className="mx-auto mb-2 text-slate-700 opacity-20" />
                <p className="text-[10px] font-bold text-slate-600 uppercase tracking-widest">No tabs found</p>
              </div>
            )
          )}
        </div>


        {/* Sidebar Footer */}
        <div className="p-4 border-t border-white/5">
          <button 
            onClick={() => setSidebarOpen(!sidebarOpen)} 
            className="flex items-center justify-center w-full p-2.5 text-slate-600 hover:text-white hover:bg-white/5 rounded-lg transition-all"
          >
            {sidebarOpen ? <ChevronLeft size={18} /> : <ChevronRight size={18} />}
          </button>
        </div>
      </aside>

      {/* --- MAIN CONTENT --- */}
      <main className="flex-1 flex flex-col overflow-hidden">
        {/* Top Navbar */}
        <header className="h-20 bg-white/80 backdrop-blur-md border-b border-slate-100 px-8 flex items-center justify-between shrink-0 z-10">
          <div className="flex flex-col">
            <h1 className="text-xl font-black text-slate-900 tracking-tight capitalize">{activeTab}</h1>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Welcome back, Admin</p>
          </div>

          <div className="flex items-center gap-6">
            <div className="relative">
              <button 
                onClick={() => setProfileDropdownOpen(!profileDropdownOpen)}
                className="flex items-center gap-3 p-1 bg-slate-50 hover:bg-slate-100 rounded-xl transition-all border border-slate-100"
              >
                <div className="w-8 h-8 bg-gradient-to-br from-orange-500 to-orange-600 rounded-lg flex items-center justify-center text-white font-bold shadow-lg shadow-orange-500/20 text-xs">
                  AD
                </div>
                <div className="text-left hidden lg:block pr-2">
                  <p className="text-[11px] font-black text-slate-900 leading-tight">Admin User</p>
                  <p className="text-[9px] text-slate-400 font-bold uppercase tracking-tighter">Super Admin</p>
                </div>
                <ChevronRight size={14} className={`text-slate-300 ml-2 transition-transform ${profileDropdownOpen ? 'rotate-90' : ''}`} />
              </button>

              {/* Profile Dropdown */}
              {profileDropdownOpen && (
                <>
                  <div 
                    className="fixed inset-0 z-10" 
                    onClick={() => setProfileDropdownOpen(false)} 
                  />
                  <div className="absolute right-0 mt-2 w-48 bg-white rounded-xl shadow-xl border border-slate-100 py-1 z-20 animate-in fade-in zoom-in-95 duration-200">
                    <div className="px-4 py-2 border-b border-slate-50">
                      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Settings</p>
                    </div>
                    <button 
                      onClick={() => {
                        setProfileDropdownOpen(false);
                        setShowLogoutConfirm(true);
                      }}
                      className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-rose-600 hover:bg-rose-50 transition-colors font-semibold"
                    >
                      <LogOut size={16} />
                      Logout Account
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </header>

        {/* Tab Content */}
        <section className="flex-1 overflow-y-auto p-4 sm:p-8 custom-scrollbar">
          <TabContent
            activeTab={activeTab}
            setActiveTab={setActiveTab}
            data={{ users, services, reviews, bookings, verifications, reports }}
          />
        </section>
      </main>

      {/* Logout Confirmation Modal */}
      {showLogoutConfirm && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-in fade-in duration-300">
          <div className="bg-white rounded-2xl w-full max-w-sm overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300">
            <div className="p-8 text-center">
              <div className="w-16 h-16 bg-rose-50 text-rose-500 rounded-full flex items-center justify-center mx-auto mb-6">
                <LogOut size={32} />
              </div>
              <h3 className="text-xl font-black text-slate-900 mb-2">Logout Confirmation</h3>
              <p className="text-sm text-slate-500 font-medium">Are you sure you want to logout? You'll need to sign in again to access the admin panel.</p>
            </div>
            <div className="flex border-t border-slate-100">
              <button 
                onClick={() => setShowLogoutConfirm(false)}
                className="flex-1 px-6 py-4 text-sm font-bold text-slate-500 hover:bg-slate-50 transition-colors border-r border-slate-100 uppercase tracking-widest"
              >
                Cancel
              </button>
              <button 
                onClick={() => {
                  signOut(auth);
                  setShowLogoutConfirm(false);
                }}
                className="flex-1 px-6 py-4 text-sm font-bold text-rose-600 hover:bg-rose-50 transition-colors uppercase tracking-widest"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function NavItem({ icon, label, active, onClick, collapsed }: any) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-3 w-full p-2.5 rounded-lg transition-all duration-300 relative group ${active
          ? 'bg-orange-500 text-white shadow-lg shadow-orange-500/20 font-bold'
          : 'text-slate-500 hover:bg-white/5 hover:text-slate-300 font-semibold'
        }`}
    >
      <div className={`shrink-0 transition-colors ${active ? 'text-white' : 'text-slate-500 group-hover:text-orange-500'}`}>{icon}</div>
      {!collapsed && <span className="text-xs">{label}</span>}
      {active && !collapsed && (
        <div className="absolute right-2 w-1.5 h-1.5 bg-white rounded-full shadow-[0_0_8px_rgba(255,255,255,0.8)]" />
      )}
    </button>
  );
}

function TabContent({ activeTab, data, setActiveTab }: any) {
  switch (activeTab) {
    case 'dashboard': return <DashboardPage data={data} setActiveTab={setActiveTab} />;
    case 'users': return <UsersPage users={data.users} bookings={data.bookings} reviews={data.reviews} pendingApprovalsCount={data.verifications.length} setActiveTab={setActiveTab} />;
    case 'reviews': return <ReviewsPage reviews={data.reviews} bookings={data.bookings} users={data.users} />;
    case 'services': return <ServicesPage services={data.services} users={data.users} bookings={data.bookings} reviews={data.reviews} />;
    case 'bookings': return <BookingsPage bookings={data.bookings} users={data.users} />;
    case 'payments': return <PaymentsPage bookings={data.bookings} users={data.users} />;
    case 'verification': return <VerificationPage requests={data.verifications} />;
    case 'reports': return <ReportsPage reports={data.reports} />;
    default: return <DashboardPage data={data} />;
  }
}

function BookingsPage({ bookings, users }: { bookings: Booking[], users: AppUser[] }) {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [selectedBooking, setSelectedBooking] = useState<Booking | null>(null);
  const [loadingAction, setLoadingAction] = useState(false);

  const handleAdminCancel = async () => {
    if (!selectedBooking) return;
    const confirm = window.confirm("Are you sure you want to officially cancel and refund this booking? This action cannot be undone.");
    if (!confirm) return;

    setLoadingAction(true);
    try {
      await updateDoc(doc(db, 'bookings', selectedBooking.id), {
        status: 'Cancelled',
        adminCancelled: true,
        cancelledAt: new Date(),
        payoutStatus: 'refunded'
      });
      alert("Booking has been successfully cancelled and marked for refund.");
      setSelectedBooking(null);
    } catch (e: any) {
      alert(`Failed to cancel booking: ${e.message}`);
    } finally {
      setLoadingAction(false);
    }
  };

  const filteredBookings = bookings.filter(b => {
    const seeker = users.find(u => u.id === b.customerId);
    const matchesSearch = 
      b.orderId?.toLowerCase().includes(search.toLowerCase()) ||
      b.serviceName?.toLowerCase().includes(search.toLowerCase()) ||
      b.providerName?.toLowerCase().includes(search.toLowerCase()) ||
      seeker?.name?.toLowerCase().includes(search.toLowerCase());
    
    const matchesStatus = statusFilter === 'All' || b.status === statusFilter;
    return matchesSearch && matchesStatus;
  }).sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0));

  const stats = {
    total: bookings.length,
    active: bookings.filter(b => ['Confirmed', 'In Progress'].includes(b.status)).length,
    completed: bookings.filter(b => b.status === 'Completed').length,
    revenue: bookings.filter(b => b.status === 'Completed').reduce((acc, b) => acc + (b.totalPrice || 0), 0)
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Pending': return 'bg-amber-50 text-amber-600 border-amber-100';
      case 'Confirmed': return 'bg-blue-50 text-blue-600 border-blue-100';
      case 'In Progress': return 'bg-indigo-50 text-indigo-600 border-indigo-100';
      case 'Completed': return 'bg-emerald-50 text-emerald-600 border-emerald-100';
      case 'Cancelled': return 'bg-rose-50 text-rose-600 border-rose-100';
      default: return 'bg-gray-50 text-gray-600 border-gray-100';
    }
  };

  const exportToCSV = () => {
    const headers = ['Order ID', 'Service', 'Provider', 'Customer', 'Date', 'Time', 'Status', 'Price', 'Fee'];
    const csvContent = [
      headers.join(','),
      ...filteredBookings.map(b => {
        const seeker = users.find(u => u.id === b.customerId);
        return [
          b.orderId || '',
          `"${b.serviceName || ''}"`,
          `"${b.providerName || ''}"`,
          `"${seeker?.name || ''}"`,
          b.date || '',
          b.time || '',
          b.status || '',
          b.totalPrice || '',
          b.chargeFee || ''
        ].join(',');
      })
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.setAttribute('download', `goserve_bookings_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
        <div className="space-y-1">
          <h1 className="text-xl font-bold text-gray-900 tracking-tight">Bookings</h1>
          <p className="text-gray-500 text-sm max-w-lg leading-relaxed">
            Monitor all service bookings and their current status across the platform.
          </p>
        </div>
        <div className="flex items-center gap-3 w-full md:w-auto">
          <button 
            onClick={exportToCSV}
            className="flex-1 md:flex-none flex items-center justify-center gap-2 px-4 py-2.5 bg-orange-500 text-white rounded-lg text-sm font-bold hover:bg-orange-600 transition-all shadow-sm shadow-orange-100"
          >
            <Download size={18} />
            Export CSV
          </button>
        </div>
      </div>

      {/* HEADER & STATS */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-blue-50 text-blue-600 rounded-lg">
              <Calendar size={24} />
            </div>
            <div>
              <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Total Bookings</p>
              <h3 className="text-2xl font-black text-gray-900">{stats.total}</h3>
            </div>
          </div>
        </div>
        <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-indigo-50 text-indigo-600 rounded-lg">
              <Clock size={24} />
            </div>
            <div>
              <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Active Now</p>
              <h3 className="text-2xl font-black text-gray-900">{stats.active}</h3>
            </div>
          </div>
        </div>
        <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-emerald-50 text-emerald-600 rounded-lg">
              <Check size={24} />
            </div>
            <div>
              <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Completed</p>
              <h3 className="text-2xl font-black text-gray-900">{stats.completed}</h3>
            </div>
          </div>
        </div>
        <div className="bg-white p-5 rounded-xl border border-gray-100 shadow-sm">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-orange-50 text-orange-600 rounded-lg">
              <DollarSign size={24} />
            </div>
            <div>
              <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Total GMV</p>
              <h3 className="text-2xl font-black text-gray-900">RM {stats.revenue.toLocaleString()}</h3>
            </div>
          </div>
        </div>
      </div>

      {/* FILTERS */}
      <div className="bg-white p-4 rounded-xl border border-gray-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative flex-1 w-full max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
          <input
            type="text"
            placeholder="Search Order ID, Service, Provider or Customer..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 bg-gray-50 border border-gray-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-orange-500/20 transition-all"
          />
        </div>
        <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto pb-2 md:pb-0">
          {['All', 'Pending', 'Confirmed', 'In Progress', 'Completed', 'Cancelled'].map((status) => (
            <button
              key={status}
              onClick={() => setStatusFilter(status)}
              className={`px-4 py-2 rounded-lg text-xs font-bold transition-all whitespace-nowrap ${statusFilter === status
                  ? 'bg-orange-500 text-white shadow-lg shadow-orange-100'
                  : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                }`}
            >
              {status}
            </button>
          ))}
        </div>
      </div>

      {/* TABLE */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="bg-gray-50/50 border-b border-gray-100">
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Booking Info</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Customer</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Status</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Payment</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Scheduled</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredBookings.map((b) => {
                const seeker = users.find(u => u.id === b.customerId);
                const platformFee = b.chargeFee || (b.totalPrice * 0.15);
                const providerEarnings = b.totalPrice - platformFee;

                return (
                  <tr key={b.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-xs font-black text-orange-600 mb-1">{b.orderId || b.id.substring(0, 8)}</p>
                        <p className="text-sm font-bold text-gray-900 truncate max-w-[200px]">{b.serviceName}</p>
                        <p className="text-[10px] font-medium text-gray-400">by {b.providerName}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center text-xs font-bold text-gray-500">
                          {seeker?.name?.[0] || 'C'}
                        </div>
                        <div>
                          <p className="text-sm font-bold text-gray-900">{seeker?.name || 'Customer'}</p>
                          <p className="text-[10px] font-medium text-gray-400">{seeker?.customId || 'Seeker'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex justify-center">
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold border uppercase tracking-wider ${getStatusColor(b.status)}`}>
                          {b.status}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-sm font-bold text-gray-900">RM {b.totalPrice?.toFixed(2)}</p>
                        <div className="flex items-center gap-1.5 mt-1">
                          <span className="text-[9px] font-bold text-emerald-600 bg-emerald-50 px-1 rounded uppercase tracking-tighter">Pro: RM {providerEarnings.toFixed(2)}</span>
                          <span className="text-[9px] font-bold text-indigo-600 bg-indigo-50 px-1 rounded uppercase tracking-tighter">Fee: RM {platformFee.toFixed(2)}</span>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex flex-col gap-1">
                        <div className="flex items-center gap-1 text-xs font-bold text-gray-700">
                          <Calendar size={12} className="text-orange-500" />
                          {b.date}
                        </div>
                        <div className="flex items-center gap-1 text-[10px] font-medium text-gray-400 uppercase tracking-widest">
                          <Clock size={12} />
                          {b.time}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <button 
                        onClick={() => setSelectedBooking(b)}
                        className="p-2 text-gray-400 hover:text-orange-500 hover:bg-orange-50 rounded-lg transition-all"
                      >
                        <Eye size={18} />
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* DETAIL MODAL */}
      {selectedBooking && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-300">
          <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-hidden flex flex-col shadow-2xl animate-in zoom-in-95 duration-300">
            {/* Modal Header */}
            <div className="p-6 border-b border-gray-100 flex items-center justify-between bg-white sticky top-0 z-10">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-orange-100 text-orange-600 rounded-xl flex items-center justify-center">
                  <FileText size={24} />
                </div>
                <div>
                  <h2 className="text-xl font-black text-gray-900 tracking-tight">Booking Details</h2>
                  <p className="text-xs font-bold text-orange-500 uppercase tracking-widest">{selectedBooking.orderId || selectedBooking.id}</p>
                </div>
              </div>
              <button onClick={() => setSelectedBooking(null)} className="p-2 hover:bg-gray-100 rounded-full transition-colors text-gray-400">
                <X size={24} />
              </button>
            </div>

            <div className="p-6 overflow-y-auto space-y-8">
              {/* Status Section */}
              <div className="flex items-center justify-between p-4 bg-gray-50 rounded-xl border border-gray-100">
                <div className="flex items-center gap-3">
                  <div className={`w-3 h-3 rounded-full animate-pulse ${
                    selectedBooking.status === 'Completed' ? 'bg-emerald-500' :
                    selectedBooking.status === 'Cancelled' ? 'bg-rose-500' : 'bg-amber-500'
                  }`} />
                  <span className="text-sm font-black text-gray-900 uppercase tracking-tight">Current Progress: {selectedBooking.status}</span>
                </div>
                <span className="text-xs font-bold text-gray-400">{selectedBooking.createdAt?.seconds ? new Date(selectedBooking.createdAt.seconds * 1000).toLocaleString() : 'N/A'}</span>
              </div>

              {/* Service & People */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                <div className="space-y-4">
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest border-l-2 border-orange-500 pl-2">Service Info</p>
                  <div className="space-y-3">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-indigo-50 text-indigo-600 rounded-lg flex items-center justify-center shrink-0">
                        <Briefcase size={20} />
                      </div>
                      <div>
                        <p className="text-xs font-bold text-gray-400">Service Category</p>
                        <p className="text-sm font-bold text-gray-900">{selectedBooking.category}</p>
                      </div>
                    </div>
                    <div>
                      <p className="text-sm font-bold text-gray-900 leading-tight">{selectedBooking.serviceName}</p>
                      <p className="text-xs text-gray-500 mt-1">Provided by <span className="font-bold text-indigo-600">{selectedBooking.providerName}</span></p>
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest border-l-2 border-blue-500 pl-2">Logistics</p>
                  <div className="space-y-3">
                    <div className="flex items-center gap-3">
                      <Calendar size={16} className="text-orange-500 shrink-0" />
                      <p className="text-sm font-bold text-gray-900">{selectedBooking.date} at {selectedBooking.time}</p>
                    </div>
                    <div className="flex items-start gap-3">
                      <MapPin size={16} className="text-orange-500 shrink-0 mt-1" />
                      <p className="text-sm font-medium text-gray-600 leading-relaxed italic">"{selectedBooking.address}"</p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Financial Breakdown */}
              <div className="space-y-4">
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest border-l-2 border-emerald-500 pl-2">Financial Breakdown</p>
                <div className="bg-white border border-gray-100 rounded-xl overflow-hidden shadow-sm">
                  <div className="p-4 space-y-3">
                    <div className="flex justify-between items-center text-sm">
                      <span className="text-gray-500 font-medium">Base Service Price</span>
                      <span className="font-bold text-gray-900">RM {selectedBooking.basePrice?.toFixed(2)}</span>
                    </div>
                    {selectedBooking.selectedAddOns?.map((add, i) => (
                      <div key={i} className="flex justify-between items-center text-sm pl-4 border-l-2 border-gray-100">
                        <span className="text-gray-400 font-medium">+ {add.name}</span>
                        <span className="font-bold text-gray-700">RM {Number(add.price).toFixed(2)}</span>
                      </div>
                    ))}
                    <div className="pt-2 border-t border-dashed border-gray-100 flex justify-between items-center text-sm">
                      <span className="text-indigo-600 font-bold">Platform Commission (15%)</span>
                      <span className="font-bold text-indigo-600">- RM {(selectedBooking.chargeFee || (selectedBooking.totalPrice * 0.15)).toFixed(2)}</span>
                    </div>
                  </div>
                  <div className="p-4 bg-emerald-50/50 border-t border-emerald-100 flex justify-between items-center">
                    <div>
                      <p className="text-[10px] font-bold text-emerald-600 uppercase tracking-widest mb-0.5">Payment to Provider</p>
                      <div className="flex items-center gap-2">
                        <Wallet size={16} className="text-emerald-600" />
                        <span className="text-lg font-black text-emerald-700">RM {(selectedBooking.totalPrice - (selectedBooking.chargeFee || (selectedBooking.totalPrice * 0.15))).toFixed(2)}</span>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-0.5">Customer Paid</p>
                      <span className="text-lg font-black text-gray-900">RM {selectedBooking.totalPrice?.toFixed(2)}</span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2 px-4 py-2 bg-gray-50 rounded-lg border border-gray-100">
                  <CreditCard size={14} className="text-gray-400" />
                  <p className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">Paid via {selectedBooking.paymentMethod?.toUpperCase() || 'Digital Payment'}</p>
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div className="p-6 border-t border-gray-100 bg-gray-50 sticky bottom-0 z-10 flex gap-3">
              {['Pending', 'Confirmed', 'In Progress'].includes(selectedBooking.status || '') && (
                <button 
                  onClick={handleAdminCancel}
                  disabled={loadingAction}
                  className="flex-1 py-3 bg-white border border-red-200 rounded-xl font-black text-sm text-red-500 hover:bg-red-50 transition-all uppercase tracking-widest flex items-center justify-center gap-2"
                >
                  {loadingAction ? <div className="animate-spin h-4 w-4 border-2 border-red-500 border-t-transparent rounded-full" /> : <Trash2 size={16} />}
                  Cancel & Refund
                </button>
              )}
              <button 
                onClick={() => setSelectedBooking(null)}
                className="flex-1 py-3 bg-slate-800 border border-slate-800 rounded-xl font-black text-sm text-white hover:bg-slate-700 transition-all uppercase tracking-widest"
              >
                Close Details
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function VerificationPage({ requests }: { requests: VerificationRequest[] }) {
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const handleStatus = async (id: string, status: 'verified' | 'rejected') => {
    setActionLoading(id);
    try {
      await updateDoc(doc(db, 'providers', id), {
        verificationStatus: status
      });
    } catch (e: any) {
      alert(`Update failed: ${e.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-lg font-bold text-gray-900 uppercase">Provider Verification</h1>
          <p className="text-gray-500 text-sm font-medium">Confirming identity for new professionals ({requests.length})</p>
        </div>
      </div>

      <div className="space-y-4">
        {requests.length === 0 ? (
          <div className="py-20 bg-white rounded-xl border border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400">
            <UserCheck size={48} className="mb-4 opacity-20" />
            <p className="font-medium">No pending verification requests</p>
            <p className="text-xs">All providers are currently up to date</p>
          </div>
        ) : requests.map((req) => (
          <div key={req.id} className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden transition-all duration-300">
            {/* COMPACT VIEW */}
            <div className="p-6 flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-orange-100 text-orange-600 rounded-lg flex items-center justify-center font-bold text-lg">
                  {req.name?.[0]?.toUpperCase()}
                </div>
                <div>
                  <h3 className="font-bold text-gray-900 leading-tight">{req.name}</h3>
                  <p className="text-xs text-gray-500">{req.email}</p>
                </div>
              </div>

              <div className="flex items-center gap-3 w-full lg:w-auto">
                <button
                  onClick={() => setExpandedId(expandedId === req.id ? null : req.id)}
                  className={`flex-1 lg:flex-none px-6 py-2.5 rounded-md font-bold text-sm transition-all flex items-center justify-center gap-2 ${expandedId === req.id
                      ? 'bg-gray-100 text-gray-700'
                      : 'bg-indigo-50 text-indigo-600 hover:bg-indigo-100'
                    }`}
                >
                  <Eye size={18} />
                  {expandedId === req.id ? 'Hide Details' : 'View Documents'}
                </button>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleStatus(req.id, 'rejected')}
                    disabled={actionLoading === req.id}
                    className="p-2.5 text-red-500 hover:bg-red-50 rounded-md transition-colors border border-red-50"
                  >
                    <Ban size={20} />
                  </button>
                  <button
                    onClick={() => handleStatus(req.id, 'verified')}
                    disabled={actionLoading === req.id}
                    className="p-2.5 bg-emerald-500 text-white rounded-md shadow-lg shadow-emerald-100 hover:bg-emerald-600 transition-all"
                  >
                    {actionLoading === req.id ? (
                      <div className="animate-spin h-5 w-5 border-2 border-white border-t-transparent rounded-full" />
                    ) : (
                      <Check size={20} />
                    )}
                  </button>
                </div>
              </div>
            </div>

            {/* EXPANDED VIEW */}
            {expandedId === req.id && (
              <div className="p-6 border-t border-gray-50 bg-gray-50/30 animate-in fade-in slide-in-from-top-4 duration-300">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Selfie Capture</p>
                    </div>
                    <div className="aspect-video bg-white rounded-lg overflow-hidden border border-gray-200 group relative shadow-md">
                      <img
                        src={req.selfieUrl}
                        alt="Selfie"
                        className="w-full h-full object-cover"
                        onClick={() => window.open(req.selfieUrl)}
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center pointer-events-none">
                        <Search size={24} className="text-white" />
                      </div>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Address Provided</p>
                    <div className="p-4 bg-white rounded-lg border border-gray-100 shadow-sm min-h-[100px] flex items-center">
                      <p className="text-sm text-gray-600 italic">"{req.address || 'No address provided by provider'}"</p>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                  <div className="space-y-2">
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">IC Front Side</p>
                    <div className="aspect-[3/2] bg-white rounded-lg overflow-hidden border border-gray-200 group relative shadow-md">
                      <img
                        src={req.icFrontUrl || req.icUrl}
                        alt="IC Front"
                        className="w-full h-full object-cover"
                        onClick={() => window.open(req.icFrontUrl || req.icUrl)}
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center pointer-events-none">
                        <Search size={24} className="text-white" />
                      </div>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">IC Back Side</p>
                    <div className="aspect-[3/2] bg-white rounded-lg overflow-hidden border border-gray-200 group relative shadow-md">
                      {req.icBackUrl ? (
                        <img
                          src={req.icBackUrl}
                          alt="IC Back"
                          className="w-full h-full object-cover"
                          onClick={() => window.open(req.icBackUrl)}
                        />
                      ) : (
                        <div className="w-full h-full flex flex-col items-center justify-center text-gray-300 gap-2">
                          <ShieldCheck size={32} className="opacity-10" />
                          <span className="text-[10px] italic">Not Provided</span>
                        </div>
                      )}
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center pointer-events-none">
                        <Search size={24} className="text-white" />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

function DashboardPage({ data, setActiveTab }: any) {
  const { users, bookings } = data;

  // Calculate actual Platform Revenue (GoServe's fees from Completed bookings)
  const totalRevenue = bookings
    .filter((b: any) => b.status === 'Completed')
    .reduce((acc: number, b: any) => acc + (Number(b.chargeFee) || 0), 0);
    
  const totalBookings = bookings.length;
  const pendingBookings = bookings.filter((b: any) => b.status === 'Pending').length;
  const completedServices = bookings.filter((b: any) => b.status === 'Completed').length;
  const totalProviders = users.filter((u: any) => u.role === 'Professional' || u.role === 'provider').length;
  const totalCustomers = users.filter((u: any) => u.role === 'Seeker' || u.role === 'customer').length;

  // --- REAL TREND CALCULATIONS ---
  const now = new Date();
  const currM = now.getMonth();
  const currY = now.getFullYear();
  const prevDate = new Date();
  prevDate.setMonth(now.getMonth() - 1);
  const prevM = prevDate.getMonth();
  const prevY = prevDate.getFullYear();

  const getStatsForMonth = (m: number, y: number) => {
    const mBookings = bookings.filter((b: any) => {
      if (!b.createdAt?.seconds) return false;
      const d = new Date(b.createdAt.seconds * 1000);
      return d.getMonth() === m && d.getFullYear() === y;
    });
    const mUsers = users.filter((u: any) => {
      if (!u.createdAt?.seconds) return false;
      const d = new Date(u.createdAt.seconds * 1000);
      return d.getMonth() === m && d.getFullYear() === y;
    });
    const mProviders = mUsers.filter((u: any) => u.role === 'Professional' || u.role === 'provider');

    return {
      revenue: mBookings.reduce((sum: number, b: any) => sum + (Number(b.totalPrice) || 0), 0),
      bookings: mBookings.length,
      users: mUsers.length,
      providers: mProviders.length,
      pending: mBookings.filter((b: any) => b.status === 'Pending').length,
      completed: mBookings.filter((b: any) => b.status === 'Completed').length,
    };
  };

  const currStats = getStatsForMonth(currM, currY);
  const prevStats = getStatsForMonth(prevM, prevY);

  const calcTrend = (curr: number, prev: number) => {
    if (prev === 0) return curr > 0 ? "+100%" : "0%";
    const pct = ((curr - prev) / prev) * 100;
    return `${pct >= 0 ? '+' : ''}${pct.toFixed(0)}%`;
  };

  // --- CHARTS DATA ---
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  
  const chartData = Array.from({ length: 6 }, (_, i) => {
    const d = new Date();
    d.setMonth(d.getMonth() - (5 - i));
    const mIdx = d.getMonth();
    const y = d.getFullYear();
    
    const mBookings = bookings.filter((b: any) => {
      if (!b.createdAt?.seconds) return false;
      const bDate = new Date(b.createdAt.seconds * 1000);
      return bDate.getMonth() === mIdx && bDate.getFullYear() === y;
    });

    return {
      name: months[mIdx],
      bookings: mBookings.length,
      revenue: mBookings.reduce((sum: number, b: any) => sum + (Number(b.totalPrice) || 0), 0),
    };
  });

  // Category Distribution for Donut Chart
  const categoryDataMap = bookings.reduce((acc: any, b: any) => {
    const cat = b.category || 'Other';
    acc[cat] = (acc[cat] || 0) + 1;
    return acc;
  }, {});

  const categoryData = Object.keys(categoryDataMap).map(cat => ({
    name: cat,
    value: categoryDataMap[cat]
  })).sort((a, b) => b.value - a.value).slice(0, 5);

  const COLORS = ['#FF6B00', '#8b5cf6', '#3b82f6', '#10b981', '#f59e0b'];

  const latestBookings = [...bookings]
    .sort((a: any, b: any) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0))
    .slice(0, 5);

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* 1. Summary Statistic Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        <StatCard 
          label="Total Users" 
          value={totalCustomers.toLocaleString()} 
          trend={calcTrend(currStats.users, prevStats.users)} 
          icon={<Users size={18} />} 
          color="text-blue-600" 
          bgColor="bg-blue-50" 
        />
        <StatCard 
          label="Providers" 
          value={totalProviders.toLocaleString()} 
          trend={calcTrend(currStats.providers, prevStats.providers)} 
          icon={<Briefcase size={18} />} 
          color="text-purple-600" 
          bgColor="bg-purple-50" 
        />
        <StatCard 
          label="Total Bookings" 
          value={totalBookings.toLocaleString()} 
          trend={calcTrend(currStats.bookings, prevStats.bookings)} 
          icon={<Calendar size={18} />} 
          color="text-amber-600" 
          bgColor="bg-amber-50" 
        />
        <StatCard 
          label="Total Revenue" 
          value={`RM ${totalRevenue.toLocaleString()}`} 
          trend={calcTrend(currStats.revenue, prevStats.revenue)} 
          icon={<DollarSign size={18} />} 
          color="text-emerald-600" 
          bgColor="bg-emerald-50" 
        />
        <StatCard 
          label="Pending" 
          value={pendingBookings.toLocaleString()} 
          icon={<Clock size={18} />} 
          color="text-rose-600" 
          bgColor="bg-rose-50" 
        />
        <StatCard 
          label="Completed" 
          value={completedServices.toLocaleString()} 
          icon={<Check size={18} />} 
          color="text-indigo-600" 
          bgColor="bg-indigo-50" 
        />
      </div>

      {/* 2. Analytics Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Monthly Booking Analytics (Line Chart) */}
        <div className="lg:col-span-2 bg-white p-6 rounded-3xl border border-slate-100 shadow-sm hover:shadow-md transition-all">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-black text-slate-900 text-base">Monthly Booking Analytics</h3>
              <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">Service request trends</p>
            </div>
            <div className="flex items-center gap-2 px-3 py-1 bg-slate-50 rounded-lg border border-slate-100">
              <div className="w-2 h-2 rounded-full bg-orange-500" />
              <span className="text-[10px] font-black text-slate-600 uppercase tracking-tighter">Bookings</span>
            </div>
          </div>
          <div className="h-[280px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <defs>
                  <linearGradient id="colorBooking" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#FF6B00" stopOpacity={0.1}/>
                    <stop offset="95%" stopColor="#FF6B00" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis 
                  dataKey="name" 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fontSize: 10, fill: '#94a3b8', fontWeight: 600 }} 
                />
                <YAxis 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fontSize: 10, fill: '#94a3b8', fontWeight: 600 }} 
                />
                <Tooltip 
                  contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' }}
                  labelStyle={{ fontWeight: 'bold', fontSize: '12px' }}
                />
                <Line 
                  type="monotone" 
                  dataKey="bookings" 
                  stroke="#FF6B00" 
                  strokeWidth={3} 
                  dot={{ r: 4, fill: '#FF6B00', strokeWidth: 2, stroke: '#fff' }} 
                  activeDot={{ r: 6, strokeWidth: 0 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Category Distribution (Donut Chart) */}
        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm hover:shadow-md transition-all flex flex-col">
          <div className="mb-6">
            <h3 className="font-black text-slate-900 text-base">Category Distribution</h3>
            <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">Most popular service areas</p>
          </div>
          <div className="flex-1 min-h-[220px] relative">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={categoryData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={80}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {categoryData.map((_entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip 
                   contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' }}
                />
              </PieChart>
            </ResponsiveContainer>
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-center pointer-events-none">
              <p className="text-xl font-black text-slate-900">{totalBookings}</p>
              <p className="text-[8px] font-bold text-slate-400 uppercase">Total</p>
            </div>
          </div>
          <div className="mt-4 space-y-2">
            {categoryData.map((entry, index) => (
              <div key={entry.name} className="flex items-center justify-between text-[11px] font-bold text-slate-600">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 rounded-full" style={{ backgroundColor: COLORS[index % COLORS.length] }} />
                  <span>{entry.name}</span>
                </div>
                <span>{((entry.value / totalBookings) * 100).toFixed(0)}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Revenue Analytics (Bar Chart) */}
        <div className="lg:col-span-2 bg-white p-6 rounded-3xl border border-slate-100 shadow-sm hover:shadow-md transition-all">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-black text-slate-900 text-base">Revenue Analytics</h3>
              <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">Financial growth performance</p>
            </div>
          </div>
          <div className="h-[280px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis 
                  dataKey="name" 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fontSize: 10, fill: '#94a3b8', fontWeight: 600 }} 
                />
                <YAxis 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fontSize: 10, fill: '#94a3b8', fontWeight: 600 }} 
                  tickFormatter={(val) => `RM ${val}`}
                />
                <Tooltip 
                  cursor={{ fill: '#f8fafc' }}
                  contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' }}
                />
                <Bar 
                  dataKey="revenue" 
                  fill="#8b5cf6" 
                  radius={[6, 6, 0, 0]} 
                  barSize={32}
                />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Latest Activity / Bookings Table (Enhanced) */}
        <div className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden flex flex-col">
          <div className="p-6 border-b border-slate-50 flex items-center justify-between">
            <h3 className="font-black text-slate-900 text-base">Recent Bookings</h3>
            <button onClick={() => setActiveTab('bookings')} className="text-[10px] font-black text-orange-500 uppercase tracking-tighter hover:underline">View All</button>
          </div>
          <div className="flex-1">
            <table className="w-full text-left">
              <tbody className="divide-y divide-slate-50">
                {latestBookings.map((b: any, i) => (
                  <tr key={b.id || i} className="hover:bg-slate-50/50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-xl bg-orange-50 flex items-center justify-center text-orange-500 shrink-0">
                          <ShoppingBag size={14} />
                        </div>
                        <div className="min-w-0">
                          <p className="text-xs font-black text-slate-900 truncate">{b.serviceName || 'Service'}</p>
                          <p className="text-[10px] text-slate-400 font-bold uppercase tracking-tighter">{b.date}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <p className="text-xs font-black text-slate-900">RM {b.totalPrice?.toLocaleString()}</p>
                      <span className={`text-[8px] font-black uppercase px-1.5 py-0.5 rounded ${
                        b.status === 'Completed' ? 'bg-emerald-50 text-emerald-600' : 
                        b.status === 'Pending' ? 'bg-amber-50 text-amber-600' : 'bg-blue-50 text-blue-600'
                      }`}>
                        {b.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, trend, icon, color, bgColor }: any) {
  return (
    <div className="bg-white p-5 rounded-3xl border border-slate-100 shadow-sm hover:shadow-md transition-all group">
      <div className="flex justify-between items-start mb-4">
        <div className={`p-2.5 rounded-2xl ${bgColor} ${color} transition-transform group-hover:scale-110 duration-300`}>
          {icon}
        </div>
        {trend && (
          <div className={`flex items-center gap-0.5 text-[10px] font-black px-2 py-0.5 rounded-full ${trend.startsWith('+') ? 'bg-emerald-50 text-emerald-600' : 'bg-rose-50 text-rose-600'}`}>
            {trend.startsWith('+') ? <TrendingUp size={10} /> : <TrendingDown size={10} />}
            {trend}
          </div>
        )}
      </div>
      <p className="text-slate-400 text-[9px] font-bold uppercase tracking-widest mb-0.5">{label}</p>
      <p className="text-xl font-black text-slate-900 tracking-tight">{value}</p>
    </div>
  );
}

function UsersPage({ users, bookings, reviews, pendingApprovalsCount, setActiveTab }: { users: AppUser[], bookings: any[], reviews: any[], pendingApprovalsCount: number, setActiveTab: (tab: string) => void }) {
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState<'All' | 'customer' | 'provider'>('All');
  const [statusFilter, setStatusFilter] = useState<'All' | 'Active' | 'Inactive' | 'Suspended'>('All');
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [activeMenu, setActiveMenu] = useState<string | null>(null);
  const [selectedUser, setSelectedUser] = useState<any | null>(null);

  const handleAction = async (uid: string, role: string, action: 'delete' | 'suspend' | 'activate') => {
    const roleMapping = role === 'Professional' ? 'Professional' : 'Seeker';
    const actionText = action === 'delete' ? 'DELETE' : action === 'suspend' ? 'SUSPEND' : 'ACTIVATE';
    
    if (!window.confirm(`⚠️ CRITICAL ACTION\n\nAre you sure you want to ${actionText} this account?\nThis action will take effect immediately.`)) return;

    setActionLoading(uid);
    setActiveMenu(null);
    try {
      const functions = getFunctions();
      if (action === 'delete') {
        const deleteFn = httpsCallable(functions, 'deleteUser');
        await deleteFn({ uid, role: roleMapping });
      } else {
        const toggleFn = httpsCallable(functions, 'toggleUserStatus');
        await toggleFn({ uid, role: roleMapping, status: action === 'suspend' ? 'Suspended' : 'Active' });
      }
    } catch (e: any) {
      console.error('Action Error:', e);
      alert(`Action failed: ${e.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const isInactive = (u: any) => {
    if (u.status === 'Suspended') return false;
    if (u.isOnline) return false;

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // If they have lastSeen, check it
    if (u.lastSeen) {
      const lastSeenDate = new Date(u.lastSeen.seconds * 1000);
      return lastSeenDate < thirtyDaysAgo;
    }

    // Fallback: If no lastSeen, check if they joined more than 30 days ago
    if (u.createdAt) {
      const joinDate = new Date(u.createdAt.seconds * 1000);
      return joinDate < thirtyDaysAgo;
    }

    return true; 
  };

  const getStatus = (u: any) => {
    if (u.status === 'Suspended') return 'Suspended';
    return isInactive(u) ? 'Inactive' : 'Active';
  };

  const filteredUsers = users
    .filter((u: any) => {
      const matchesSearch = !search || 
                            u.name?.toLowerCase().includes(search.toLowerCase()) || 
                            u.email?.toLowerCase().includes(search.toLowerCase()) ||
                            u.customId?.toLowerCase().includes(search.toLowerCase());
      const matchesRole = roleFilter === 'All' || u.role?.toLowerCase() === roleFilter.toLowerCase();
      const matchesStatus = statusFilter === 'All' || getStatus(u) === statusFilter;
      return matchesSearch && matchesRole && matchesStatus;
    })
    .sort((a: any, b: any) => {
      const dateA = a.createdAt?.seconds || 0;
      const dateB = b.createdAt?.seconds || 0;
      return dateB - dateA;
    });

  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 5; // Showing 5 per page for better layout
  const totalPages = Math.ceil(filteredUsers.length / pageSize);
  const paginatedUsers = filteredUsers.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  const getPageNumbers = () => {
    const pages = [];
    if (totalPages <= 5) {
      for (let i = 1; i <= totalPages; i++) pages.push(i);
    } else {
      if (currentPage <= 3) {
        pages.push(1, 2, 3, '...', totalPages);
      } else if (currentPage >= totalPages - 2) {
        pages.push(1, '...', totalPages - 2, totalPages - 1, totalPages);
      } else {
        pages.push(1, '...', currentPage, '...', totalPages);
      }
    }
    return pages;
  };

  // Reset page when filters change
  useEffect(() => {
    setCurrentPage(1);
  }, [search, roleFilter, statusFilter]);

  // Growth Metrics (Derived from real data)
  const now = new Date();
  const last30Days = new Date(now.setDate(now.getDate() - 30));
  const newRegistrationsCount = users.filter(u => u.createdAt && new Date(u.createdAt.seconds * 1000) > last30Days).length;
  const providerOnboardingCount = users.filter(u => u.role === 'Professional' && u.createdAt && new Date(u.createdAt.seconds * 1000) > last30Days).length;



  const exportToCSV = () => {
    const headers = ['User ID', 'Name', 'Email', 'Role', 'Status', 'Joined Date'];
    const rows = filteredUsers.map(u => [
      `"${u.customId || 'N/A'}"`,
      `"${u.name || 'Anonymous'}"`,
      `"${u.email || 'N/A'}"`,
      u.role === 'Professional' ? 'Provider' : 'User',
      getStatus(u),
      u.createdAt ? new Date(u.createdAt.seconds * 1000).toLocaleDateString() : 'N/A'
    ]);
    
    const csvContent = [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `GoServe_Members_${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
  };

  return (
    <div className="space-y-8 pb-10">
      {/* HEADER SECTION */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
        <div className="space-y-1">
          <h1 className="text-xl font-bold text-gray-900 tracking-tight">User Management</h1>
          <p className="text-gray-500 text-sm max-w-lg leading-relaxed">
            Manage all system users and service providers, monitor their status, and control access permissions.
          </p>
        </div>
        <div className="flex items-center gap-3 w-full md:w-auto">

          <button 
            onClick={exportToCSV}
            className="flex-1 md:flex-none flex items-center justify-center gap-2 px-4 py-2.5 bg-orange-500 text-white rounded-lg text-sm font-bold hover:bg-orange-600 transition-all shadow-sm shadow-orange-100"
          >
            <Download size={18} />
            Export CSV
          </button>
        </div>
      </div>

      {/* FILTER BAR */}
      <div className="bg-white p-4 rounded-xl border border-gray-100 shadow-sm flex items-center justify-between gap-4">
        <div className="flex items-center gap-4 flex-1">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
            <input
              type="text"
              placeholder="Search name, email, or ID..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-orange-500/20 transition-all"
            />
          </div>

          <div className="h-6 w-[1px] bg-gray-200 mx-2" />

          <div className="relative">
            <select 
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value as any)}
              className="appearance-none pl-4 pr-10 py-2 bg-white border border-gray-200 rounded-lg text-sm font-semibold text-gray-700 focus:outline-none focus:ring-2 focus:ring-orange-500/20 cursor-pointer"
            >
              <option value="All">All Roles</option>
              <option value="customer">Customers</option>
              <option value="provider">Providers</option>
            </select>
            <ChevronRight size={14} className="absolute right-3 top-1/2 -translate-y-1/2 rotate-90 text-gray-400 pointer-events-none" />
          </div>

          <div className="relative">
            <select 
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="appearance-none pl-4 pr-10 py-2 bg-white border border-gray-200 rounded-lg text-sm font-semibold text-gray-700 focus:outline-none focus:ring-2 focus:ring-orange-500/20 cursor-pointer"
            >
              <option value="All">All Statuses</option>
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
              <option value="Suspended">Suspended</option>
            </select>
            <ChevronRight size={14} className="absolute right-3 top-1/2 -translate-y-1/2 rotate-90 text-gray-400 pointer-events-none" />
          </div>

        </div>

        <button 
          onClick={() => {
            setSearch('');
            setRoleFilter('All');
            setStatusFilter('All');
          }}
          className="flex items-center gap-2 text-gray-400 hover:text-gray-600 font-bold text-sm transition-colors"
        >
          <RotateCcw size={16} />
          Reset
        </button>
      </div>

      {/* TABLE SECTION */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="px-8 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">Name & Contact</th>
                <th className="px-6 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">User ID</th>
                <th className="px-6 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">Role</th>
                <th className="px-6 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">Status</th>
                <th className="px-6 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider">Joined</th>
                <th className="px-8 py-5 text-[11px] font-bold uppercase text-gray-400 tracking-wider text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredUsers.length === 0 ? (
                <tr><td colSpan={6} className="p-20 text-center text-gray-400 font-medium">No members found matching your criteria.</td></tr>
              ) : (
                <>
                  {paginatedUsers.map((u: any) => (
                    <tr key={u.id} className="group hover:bg-gray-50/50 transition-colors">
                      <td className="px-8 py-5">
                        <div className="flex items-center gap-4">
                          <div className="relative">
                            <div className="w-11 h-11 rounded-full bg-gray-100 border-2 border-white shadow-sm overflow-hidden">
                              {u.profileUrl ? (
                                <img src={u.profileUrl} alt={u.name} className="w-full h-full object-cover" />
                              ) : (
                                <div className="w-full h-full flex items-center justify-center font-bold text-gray-400">
                                  {u.name?.[0]?.toUpperCase() || '?'}
                                </div>
                              )}
                            </div>
                          </div>
                          <div>
                            <div className="flex items-center gap-1.5 mb-1">
                              <p className="font-bold text-[15px] text-gray-900 leading-none">{u.name || 'Anonymous Member'}</p>
                              {u.verificationStatus === 'verified' && (
                                <ShieldCheck size={14} className="text-blue-500" />
                              )}
                            </div>
                            <p className="text-sm text-gray-500">{u.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-5 text-sm font-semibold text-gray-600">
                        {u.customId || "Pending"}
                      </td>
                      <td className="px-6 py-5">
                        <span className={`px-2.5 py-1 rounded-md text-[10px] font-bold uppercase tracking-wider border ${
                          u.role?.toLowerCase() === 'provider' 
                            ? 'bg-indigo-50/50 text-indigo-600 border-indigo-100' 
                            : 'bg-orange-50/30 text-orange-600 border-orange-100'
                        }`}>
                          {u.role || 'User'}
                        </span>
                      </td>
                      <td className="px-6 py-5">
                        <div className="flex items-center gap-2">
                          <div className={`w-1.5 h-1.5 rounded-full ${
                            u.status === 'Suspended' ? 'bg-rose-500' : 
                            isInactive(u) ? 'bg-gray-400' : 'bg-emerald-500'
                          }`} />
                          <span className={`text-sm font-bold ${
                            u.status === 'Suspended' ? 'text-rose-600' : 
                            isInactive(u) ? 'text-gray-500' : 'text-emerald-600'
                          }`}>
                            {getStatus(u)}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-5 text-sm font-semibold text-gray-600">
                        {u.createdAt ? new Date(u.createdAt.seconds * 1000).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : '---'}
                      </td>
                      <td className="px-8 py-5 text-right relative">
                        <div className="flex items-center justify-end gap-2 text-gray-400">
                          <button onClick={() => setSelectedUser(u)} className="p-2 hover:bg-gray-50 rounded-lg transition-colors hover:text-gray-600">
                            <FileText size={18} />
                          </button>
                          
                          <div className="relative">
                            <button 
                              onClick={() => setActiveMenu(activeMenu === u.id ? null : u.id)}
                              className={`p-2 rounded-lg transition-colors hover:text-gray-600 ${activeMenu === u.id ? 'bg-gray-100 text-gray-900' : 'hover:bg-gray-50'}`}
                            >
                              <MoreVertical size={18} />
                            </button>

                            {activeMenu === u.id && (
                              <>
                                <div className="fixed inset-0 z-10" onClick={() => setActiveMenu(null)} />
                                <div className="absolute right-0 mt-2 w-56 bg-white rounded-xl shadow-2xl border border-gray-100 py-2 z-20 animate-in fade-in zoom-in-95 duration-150 origin-top-right">
                                  <div className="px-4 py-2 mb-1 border-b border-gray-50">
                                    <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Account Actions</p>
                                  </div>
                                  <button
                                    onClick={() => handleAction(u.id, u.role, u.status === 'Suspended' ? 'activate' : 'suspend')}
                                    className="w-full px-4 py-2.5 text-left text-sm font-bold text-gray-700 hover:bg-gray-50 flex items-center gap-3 transition-colors"
                                  >
                                    {u.status === 'Suspended' ? <Check size={18} className="text-emerald-500" /> : <Ban size={18} className="text-amber-500" />}
                                    {u.status === 'Suspended' ? 'Activate Account' : 'Suspend Account'}
                                  </button>
                                  <button
                                    onClick={() => handleAction(u.id, u.role, 'delete')}
                                    className="w-full px-4 py-2.5 text-left text-sm font-bold text-red-600 hover:bg-red-50 flex items-center gap-3 transition-colors"
                                  >
                                    <Trash2 size={18} />
                                    Delete Account
                                  </button>
                                </div>
                              </>
                            )}
                          </div>
                        </div>
                        {actionLoading === u.id && (
                          <div className="absolute inset-0 bg-white/60 backdrop-blur-[1px] flex items-center justify-center z-30">
                            <div className="animate-spin h-5 w-5 border-2 border-orange-500 border-t-transparent rounded-full" />
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                  
                  {/* EMPTY ROWS TO MAINTAIN HEIGHT */}
                  {Array.from({ length: pageSize - paginatedUsers.length }).map((_, index) => (
                    <tr key={`empty-${index}`} className="h-[85px] border-b border-gray-50 last:border-0">
                      <td colSpan={5} className="px-6 py-5" />
                    </tr>
                  ))}
                </>
              )}
            </tbody>
          </table>
        </div>

        {/* PAGINATION */}
        <div className="p-6 border-t border-gray-50 flex items-center justify-between">
          <p className="text-sm font-semibold text-gray-500">
            Showing <span className="text-gray-900 font-bold">{filteredUsers.length === 0 ? 0 : (currentPage - 1) * pageSize + 1}-{Math.min(currentPage * pageSize, filteredUsers.length)}</span> of <span className="text-gray-900 font-bold">{filteredUsers.length.toLocaleString()}</span> members
          </p>
          <div className="flex items-center gap-1.5">
            <button 
              onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
              disabled={currentPage === 1}
              className={`p-2 border border-gray-100 rounded-lg transition-colors ${currentPage === 1 ? 'text-gray-200 cursor-not-allowed' : 'text-gray-500 hover:bg-gray-50'}`}
            >
              <ChevronLeft size={18} />
            </button>
            
            {getPageNumbers().map((p, i) => (
              p === '...' ? (
                <span key={`dots-${i}`} className="text-gray-400 px-1">...</span>
              ) : (
                <button
                  key={p}
                  onClick={() => setCurrentPage(p as number)}
                  className={`w-9 h-9 flex items-center justify-center rounded-lg font-bold text-sm transition-all ${
                    currentPage === p 
                      ? 'bg-orange-500 text-white shadow-md' 
                      : 'hover:bg-gray-50 text-gray-600'
                  }`}
                >
                  {p}
                </button>
              )
            ))}

            <button 
              onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
              disabled={currentPage === totalPages || totalPages === 0}
              className={`p-2 border border-gray-100 rounded-lg transition-colors ${currentPage === totalPages || totalPages === 0 ? 'text-gray-200 cursor-not-allowed' : 'text-gray-500 hover:bg-gray-50'}`}
            >
              <ChevronRight size={18} />
            </button>
          </div>
        </div>
      </div>

      {/* BOTTOM SECTION */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-stretch">
        <div className="lg:col-span-2 bg-white p-8 rounded-xl border border-gray-100 shadow-sm flex flex-col justify-between">
          <div>
            <h3 className="text-lg font-bold text-gray-900 mb-1">Growth Overview</h3>
            <p className="text-gray-400 text-xs font-medium mb-12">Performance metrics for the current billing cycle.</p>
          </div>
          
          <div className="grid grid-cols-3 gap-4">
            <div>
              <p className="text-3xl font-extrabold text-orange-500 mb-1">{newRegistrationsCount.toLocaleString()}</p>
              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">New Registrations</p>
            </div>
            <div>
              <p className="text-3xl font-extrabold text-gray-900 mb-1">{providerOnboardingCount.toLocaleString()}</p>
              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Provider Onboarding</p>
            </div>
            <div>
              <p className="text-3xl font-extrabold text-emerald-500 mb-1">+12%</p>
              <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Monthly Growth</p>
            </div>
          </div>
        </div>

        <div className="bg-orange-500 p-8 rounded-xl text-white shadow-xl shadow-orange-100 flex flex-col justify-between relative overflow-hidden">
          <div className="absolute top-0 right-0 p-8 opacity-10">
            <ShieldCheck size={120} className="translate-x-1/4 -translate-y-1/4" />
          </div>
          
          <div className="relative z-10">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-lg font-bold">Pending Approvals</h3>
              <ShieldCheck size={20} />
            </div>
            <p className="text-orange-100 text-xs font-medium mb-10">Verification queue is active</p>
          </div>

          <div className="relative z-10 space-y-6">
            <div className="flex items-baseline gap-2">
              <span className="text-5xl font-extrabold">{pendingApprovalsCount}</span>
              <span className="text-sm font-bold opacity-80">Providers</span>
            </div>
            <button 
              onClick={() => setActiveTab('verification')}
              className="w-full py-3 bg-white text-orange-500 rounded-lg font-bold text-sm hover:bg-orange-50 transition-all shadow-lg"
            >
              Start Review
            </button>
          </div>
        </div>
      </div>
      {/* USER PROFILE MODAL */}
      {selectedUser && (
        <UserProfilePage 
          user={selectedUser} 
          bookings={bookings} 
          reviews={reviews}
          onClose={() => setSelectedUser(null)} 
          getStatus={getStatus}
        />
      )}
    </div>
  );
}

function UserProfilePage({ user, bookings, reviews, onClose, getStatus }: any) {
  // Calculate user-specific stats
  const userBookings = bookings.filter((b: any) => 
    b.customerId === user.id || b.providerId === user.id
  );
  const completedBookings = userBookings.filter((b: any) => b.status === 'completed');
  
  const userReviews = reviews.filter((r: any) => r.providerId === user.id);
  const avgRating = userReviews.length > 0 
    ? (userReviews.reduce((sum: number, r: any) => sum + (r.rating || 0), 0) / userReviews.length) 
    : (user.rating || 0);
  
  const totalEarnings = completedBookings
    .filter((b: any) => b.providerId === user.id)
    .reduce((sum: number, b: any) => sum + (parseFloat(b.totalPrice || b.price || '0')), 0);

  const isProvider = user.role?.toLowerCase() === 'provider';

  // Sort bookings by date for recent activity
  const recentBookings = [...userBookings]
    .sort((a: any, b: any) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0))
    .slice(0, 5);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm" onClick={onClose}>
      <div 
        className="relative bg-white w-full max-w-3xl max-h-[90vh] rounded-2xl overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header Banner */}
        <div className={`relative h-32 ${isProvider ? 'bg-gradient-to-r from-indigo-500 to-indigo-600' : 'bg-gradient-to-r from-orange-400 to-orange-500'}`}>
          <button 
            onClick={onClose} 
            className="absolute top-4 right-4 p-2 bg-white/20 hover:bg-white/30 rounded-lg text-white transition-all"
          >
            <X size={18} />
          </button>
          <div className="absolute top-4 left-4 flex items-center gap-2">
            <button onClick={onClose} className="p-2 bg-white/20 hover:bg-white/30 rounded-lg text-white transition-all">
              <ArrowLeft size={18} />
            </button>
            <span className="text-white/80 text-sm font-semibold">User Profile</span>
          </div>
        </div>

        {/* Profile Info */}
        <div className="px-8 -mt-12 relative z-10">
          <div className="flex items-end gap-5">
            <div className="w-24 h-24 rounded-2xl bg-white border-4 border-white shadow-lg overflow-hidden shrink-0">
              {user.profileUrl ? (
                <img src={user.profileUrl} alt={user.name} className="w-full h-full object-cover" />
              ) : (
                <div className={`w-full h-full flex items-center justify-center text-2xl font-bold text-white ${isProvider ? 'bg-indigo-400' : 'bg-orange-400'}`}>
                  {user.name?.[0]?.toUpperCase() || '?'}
                </div>
              )}
            </div>
            <div className="pb-1 flex-1">
              <div className="flex items-center gap-3 mb-1">
                <h2 className="text-xl font-bold text-gray-900">{user.name || 'Anonymous'}</h2>
                {user.verificationStatus === 'verified' && (
                  <ShieldCheck size={16} className="text-blue-500" />
                )}
                <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider border ${
                  isProvider 
                    ? 'bg-indigo-50/50 text-indigo-600 border-indigo-100' 
                    : 'bg-orange-50/30 text-orange-600 border-orange-100'
                }`}>
                  {user.role || 'customer'}
                </span>
              </div>
              <p className="text-sm text-gray-500 font-medium">{user.customId || 'No ID'} · Joined {user.createdAt ? new Date(user.createdAt.seconds * 1000).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : '---'}</p>
            </div>
            <div className="pb-1">
              <div className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-bold ${
                getStatus(user) === 'Active' ? 'bg-emerald-50 text-emerald-600' :
                getStatus(user) === 'Suspended' ? 'bg-rose-50 text-rose-600' :
                'bg-gray-50 text-gray-500'
              }`}>
                <div className={`w-1.5 h-1.5 rounded-full ${
                  getStatus(user) === 'Active' ? 'bg-emerald-500' :
                  getStatus(user) === 'Suspended' ? 'bg-rose-500' :
                  'bg-gray-400'
                }`} />
                {getStatus(user)}
              </div>
            </div>
          </div>
        </div>

        {/* Contact Details */}
        <div className="px-8 mt-6">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
              <div className="p-2 bg-white rounded-lg shadow-sm">
                <Mail size={16} className="text-gray-400" />
              </div>
              <div className="min-w-0">
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Email</p>
                <p className="text-sm font-semibold text-gray-700 truncate">{user.email || '---'}</p>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
              <div className="p-2 bg-white rounded-lg shadow-sm">
                <Phone size={16} className="text-gray-400" />
              </div>
              <div className="min-w-0">
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Phone</p>
                <p className="text-sm font-semibold text-gray-700 truncate">{user.phone || '---'}</p>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
              <div className="p-2 bg-white rounded-lg shadow-sm">
                <MapPin size={16} className="text-gray-400" />
              </div>
              <div className="min-w-0">
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Address</p>
                <p className="text-sm font-semibold text-gray-700 truncate">{user.address || '---'}</p>
              </div>
            </div>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="px-8 mt-6">
          <div className={`grid ${isProvider ? 'grid-cols-3' : 'grid-cols-2'} gap-4`}>
            <div className="bg-white border border-gray-100 rounded-xl p-5 shadow-sm">
              <div className="flex items-center gap-3 mb-3">
                <div className="p-2 bg-blue-50 rounded-lg">
                  <Calendar size={16} className="text-blue-500" />
                </div>
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Total Bookings</p>
              </div>
              <p className="text-2xl font-bold text-gray-900">{userBookings.length}</p>
              <p className="text-xs text-gray-400 mt-1">{completedBookings.length} completed</p>
            </div>
            <div className="bg-white border border-gray-100 rounded-xl p-5 shadow-sm">
              <div className="flex items-center gap-3 mb-3">
                <div className="p-2 bg-amber-50 rounded-lg">
                  <Star size={16} className="text-amber-500" />
                </div>
                <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Average Rating</p>
              </div>
              <p className="text-2xl font-bold text-gray-900">{avgRating.toFixed(1)}</p>
              <p className="text-xs text-gray-400 mt-1">{userReviews.length} reviews</p>
            </div>
            {isProvider && (
              <div className="bg-white border border-gray-100 rounded-xl p-5 shadow-sm">
                <div className="flex items-center gap-3 mb-3">
                  <div className="p-2 bg-emerald-50 rounded-lg">
                    <DollarSign size={16} className="text-emerald-500" />
                  </div>
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Total Earnings</p>
                </div>
                <p className="text-2xl font-bold text-gray-900">RM {totalEarnings.toFixed(2)}</p>
                <p className="text-xs text-gray-400 mt-1">From {completedBookings.filter((b: any) => b.providerId === user.id).length} orders</p>
              </div>
            )}
          </div>
        </div>

        {/* Recent Activity */}
        <div className="px-8 mt-6 pb-8">
          <h3 className="text-sm font-bold text-gray-900 mb-4 flex items-center gap-2">
            <Clock size={14} className="text-gray-400" />
            Recent Activity
          </h3>
          {recentBookings.length === 0 ? (
            <div className="text-center py-8 text-gray-400">
              <Calendar size={28} className="mx-auto mb-2 opacity-50" />
              <p className="text-sm font-medium">No activity yet</p>
            </div>
          ) : (
            <div className="space-y-3">
              {recentBookings.map((b: any) => (
                <div key={b.id} className="flex items-center gap-4 p-3 bg-gray-50 rounded-xl hover:bg-gray-100/80 transition-colors">
                  <div className={`p-2 rounded-lg shrink-0 ${
                    b.status === 'completed' ? 'bg-emerald-50' :
                    b.status === 'cancelled' ? 'bg-rose-50' :
                    'bg-blue-50'
                  }`}>
                    <Briefcase size={14} className={
                      b.status === 'completed' ? 'text-emerald-500' :
                      b.status === 'cancelled' ? 'text-rose-500' :
                      'text-blue-500'
                    } />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-800 truncate">{b.serviceName || b.serviceTitle || 'Service Booking'}</p>
                    <p className="text-xs text-gray-400">
                      {b.createdAt ? new Date(b.createdAt.seconds * 1000).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : '---'}
                    </p>
                  </div>
                  <span className={`px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider ${
                    b.status === 'completed' ? 'bg-emerald-50 text-emerald-600' :
                    b.status === 'cancelled' ? 'bg-rose-50 text-rose-600' :
                    b.status === 'pending' ? 'bg-amber-50 text-amber-600' :
                    'bg-blue-50 text-blue-600'
                  }`}>
                    {b.status || 'pending'}
                  </span>
                  {b.totalPrice && (
                    <span className="text-sm font-bold text-gray-700">RM {parseFloat(b.totalPrice || b.price || '0').toFixed(2)}</span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function convertTimeTo24h(timeStr: string): string {
  if (!timeStr) return '00:00:00';
  const match = timeStr.match(/^(\d+):(\d+)\s*(AM|PM)$/i);
  if (!match) return '00:00:00';
  let hours = parseInt(match[1], 10);
  const minutes = match[2];
  const ampm = match[3].toUpperCase();
  if (ampm === 'PM' && hours < 12) hours += 12;
  if (ampm === 'AM' && hours === 12) hours = 0;
  return `${hours.toString().padStart(2, '0')}:${minutes}:00`;
}

function ReviewsPage({ reviews, bookings = [], users = [] }: any) {
  const [statusFilter, setStatusFilter] = useState('All');
  const [sortOrder, setSortOrder] = useState<'desc' | 'asc'>('desc');
  
  const filteredReviews = reviews.filter((r: any) => {
    if (statusFilter === 'All') return true;
    const status = r.status || 'Pending';
    return status === statusFilter;
  }).sort((a: any, b: any) => {
    const timeA = a.createdAt?.seconds || (a.createdAt?._seconds) || 0;
    const timeB = b.createdAt?.seconds || (b.createdAt?._seconds) || 0;
    return sortOrder === 'desc' ? timeB - timeA : timeA - timeB;
  });

  const handleStatus = async (id: string, status: 'Approved' | 'Rejected') => {
    try {
      await updateDoc(doc(db, 'reviews', id), { status });
      
      const review = reviews.find((r: any) => r.id === id);
      if (review && review.serviceId) {
        const serviceId = review.serviceId;
        const q = query(
          collection(db, 'reviews'),
          where('serviceId', '==', serviceId),
          where('status', '==', 'Approved')
        );
        const snapshot = await getDocs(q);
        const approvedReviews = snapshot.docs.map((doc: any) => doc.data());
        
        const count = approvedReviews.length;
        const avg = count > 0 
          ? approvedReviews.reduce((sum: number, r: any) => sum + (r.rating || 0), 0) / count 
          : 0;

        await updateDoc(doc(db, 'services', serviceId), {
          averageRating: avg,
          reviewCount: count
        });
      }
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-lg font-bold text-gray-900 uppercase">Review Board</h1>
          <p className="text-gray-500 text-sm font-medium">Moderating Marketplace Veracity</p>
        </div>
        <div className="flex items-center gap-4">
          <select 
            value={sortOrder} 
            onChange={(e) => setSortOrder(e.target.value as 'desc' | 'asc')}
            className="px-3 py-1.5 bg-white border border-gray-200 rounded-lg text-xs font-bold text-gray-700 outline-none hover:border-orange-200 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 transition-all cursor-pointer"
          >
            <option value="desc">Newest First</option>
            <option value="asc">Oldest First</option>
          </select>

          <div className="flex gap-2 bg-gray-50 p-1 rounded-lg border border-gray-100">
            {['All', 'Pending', 'Approved', 'Rejected'].map(s => (
              <button 
                key={s}
                onClick={() => setStatusFilter(s)}
                className={`px-4 py-1.5 rounded-md text-xs font-bold transition-all ${
                  statusFilter === s 
                    ? 'bg-white text-orange-600 shadow-sm border border-gray-200/60' 
                    : 'text-gray-500 hover:text-gray-700 hover:bg-gray-200/50 border border-transparent'
                }`}
              >
                {s}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="bg-gray-50/50 border-b border-gray-100">
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Review</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Order & Users</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Status</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredReviews.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-6 py-20 text-center text-gray-400">No reviews found for this filter.</td>
                </tr>
              ) : filteredReviews.map((r: any) => {
                let booking = bookings.find((b: any) => b.id === r.bookingId || b.bookingId === r.bookingId);
                if (!booking) {
                  const candidateBookings = bookings.filter((b: any) => 
                    b.customerId === r.userId && 
                    b.providerId === r.providerId
                  );
                  
                  if (candidateBookings.length > 0) {
                    candidateBookings.sort((x: any, y: any) => {
                      const secondsX = x.createdAt?.seconds || (x.createdAt?._seconds) || 0;
                      const secondsY = y.createdAt?.seconds || (y.createdAt?._seconds) || 0;
                      if (secondsX && secondsY) return secondsY - secondsX;
                      
                      const timeX = x.date ? new Date(`${x.date}T${x.time ? convertTimeTo24h(x.time) : '00:00:00'}`).getTime() : 0;
                      const timeY = y.date ? new Date(`${y.date}T${y.time ? convertTimeTo24h(y.time) : '00:00:00'}`).getTime() : 0;
                      return timeY - timeX;
                    });

                    booking = candidateBookings.find((b: any) => 
                      (b.serviceName && r.serviceName && b.serviceName.toLowerCase() === r.serviceName.toLowerCase()) ||
                      (b.serviceTitle && r.serviceName && b.serviceTitle.toLowerCase() === r.serviceName.toLowerCase())
                    );
                    
                    if (!booking) {
                      booking = candidateBookings[0];
                    }
                  }
                }
                const orderId = r.orderId || (booking ? (booking.orderId || booking.id.substring(0, 8).toUpperCase()) : (r.bookingId ? r.bookingId.substring(0, 8).toUpperCase() : 'N/A'));
                const customer = users.find((u: any) => u.id === r.userId);
                const customerName = customer ? customer.name : (r.customerName || r.userName || 'Customer');
                const provider = users.find((u: any) => u.id === r.providerId);
                const providerName = provider ? (provider.name || provider.companyName) : (booking ? booking.providerName : (r.providerName || 'Provider'));

                return (
                  <tr key={r.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-1 mb-1">
                        {[...Array(5)].map((_, i) => (
                          <Star key={i} size={14} fill={i < r.rating ? "#f59e0b" : "#e2e8f0"} className={i < r.rating ? "text-amber-500" : "text-gray-200"} />
                        ))}
                      </div>
                      <p className="font-bold text-gray-900 text-sm mt-1">{r.serviceName || 'Service'}</p>
                      <p className="text-xs text-gray-600 mt-1 italic max-w-sm">"{r.comment}"</p>
                    </td>
                    <td className="px-6 py-4">
                      <div className="space-y-1">
                        <p className="text-xs font-mono font-bold text-orange-600">{orderId}</p>
                        <p className="text-xs text-gray-700"><span className="text-gray-400 font-semibold mr-1">C:</span>{customerName}</p>
                        <p className="text-xs text-gray-700"><span className="text-gray-400 font-semibold mr-1">P:</span>{providerName}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className={`text-[10px] font-bold uppercase px-2 py-1 rounded inline-block ${
                        r.status === 'Approved' ? 'bg-emerald-50 text-emerald-600' : 
                        r.status === 'Rejected' ? 'bg-red-50 text-red-600' : 
                        'bg-orange-50 text-orange-600'
                      }`}>
                        {r.status || 'Pending'}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex justify-end gap-2">
                        <button 
                          onClick={() => handleStatus(r.id, 'Approved')} 
                          className="px-4 py-1.5 bg-emerald-50 text-emerald-600 hover:bg-emerald-500 hover:text-white rounded-md font-bold text-xs transition-colors"
                        >
                          Approve
                        </button>
                        <button 
                          onClick={() => handleStatus(r.id, 'Rejected')} 
                          className="px-4 py-1.5 border border-red-100 text-red-500 hover:bg-red-50 rounded-md font-bold text-xs transition-colors"
                        >
                          Reject
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function ServicesPage({ services, users, bookings, reviews }: { services: Service[], users: AppUser[], bookings: any[], reviews: any[] }) {
  const [selectedService, setSelectedService] = useState<Service | null>(null);
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All');
  const [layout, setLayout] = useState<'grid' | 'list'>('grid');
  const [isMigrating, setIsMigrating] = useState(false);

  const migrateServiceIds = async () => {
    if (!window.confirm("This will assign SVCXXX IDs to all services that don't have one. Continue?")) return;
    
    setIsMigrating(true);
    try {
      // Use existing services from props to find max ID
      let maxNum = 0;
      services.forEach(s => {
        if (s.customId && s.customId.startsWith('SVC')) {
          const numPart = s.customId.substring(3);
          const num = parseInt(numPart);
          if (!isNaN(num) && num > maxNum) maxNum = num;
        }
      });

      // Find services without customId
      const toFix = services.filter(s => !s.customId);
      
      if (toFix.length === 0) {
        alert("All services already have custom IDs.");
        return;
      }

      const batch = writeBatch(db);
      toFix.forEach((s) => {
        maxNum++;
        const newId = `SVC${maxNum.toString().padStart(3, '0')}`;
        const ref = doc(db, 'services', s.id);
        batch.update(ref, { customId: newId });
      });

      await batch.commit();
      alert(`Successfully migrated ${toFix.length} services.`);
    } catch (e: any) {
      console.error(e);
      alert(`Migration failed: ${e.message}`);
    } finally {
      setIsMigrating(false);
    }
  };

  const recalculateRatings = async () => {
    if (!window.confirm("This will recalculate ratings and review counts for all services based on approved reviews. Continue?")) return;
    
    setIsMigrating(true);
    try {
      const batch = writeBatch(db);
      let updatedCount = 0;

      for (const s of services) {
        const serviceReviews = reviews.filter(r => r.serviceId === s.id && r.status === 'Approved');
        const count = serviceReviews.length;
        const avg = count > 0 
          ? serviceReviews.reduce((sum, r) => sum + (r.rating || 0), 0) / count 
          : 0;

        const ref = doc(db, 'services', s.id);
        batch.update(ref, { 
          averageRating: avg,
          reviewCount: count
        });
        updatedCount++;
      }

      await batch.commit();
      alert(`Successfully updated ratings for ${updatedCount} services.`);
    } catch (e: any) {
      console.error(e);
      alert(`Recalculation failed: ${e.message}`);
    } finally {
      setIsMigrating(false);
    }
  };

  const getServiceStats = (serviceId: string) => {
    const serviceBookings = bookings.filter(b => b.serviceId === serviceId);
    const serviceReviews = reviews.filter(r => r.serviceId === serviceId);
    const avgRating = serviceReviews.length > 0 
      ? serviceReviews.reduce((sum, r) => sum + (r.rating || 0), 0) / serviceReviews.length
      : 0;
    
    return {
      totalBookings: serviceBookings.length,
      avgRating: avgRating.toFixed(1),
      reviewCount: serviceReviews.length
    };
  };
  const categories = [
    'Home Services', 
    'Electrical & Wiring', 
    'Automotive', 
    'Moving', 
    'Health', 
    'Pet Services', 
    'Safety', 
    'Event',
    'Others'
  ];

  const toggleStatus = async (id: string, current: boolean) => {
    try {
      await updateDoc(doc(db, 'services', id), {
        isActive: !current
      });
    } catch (e) {
      console.error(e);
    }
  };

  const handleDeleteService = async (id: string) => {
    if (!window.confirm("Are you sure you want to permanently delete this service? This will remove it from the platform entirely.")) return;
    try {
      const { deleteDoc } = await import('firebase/firestore');
      await deleteDoc(doc(db, 'services', id));
      alert("Service deleted successfully.");
      setSelectedService(null);
    } catch (e: any) {
      alert(`Failed to delete service: ${e.message}`);
    }
  };

  const filteredServices = services.filter(s => {
    const provider = users.find(u => u.id === s.providerId);
    const matchesSearch = !search || 
      s.title?.toLowerCase().includes(search.toLowerCase()) ||
      s.description?.toLowerCase().includes(search.toLowerCase()) ||
      s.providerName?.toLowerCase().includes(search.toLowerCase()) ||
      s.providerId?.toLowerCase().includes(search.toLowerCase()) ||
      provider?.customId?.toLowerCase().includes(search.toLowerCase()) ||
      s.id?.toLowerCase().includes(search.toLowerCase()) ||
      s.customId?.toLowerCase().includes(search.toLowerCase());
    
    const matchesCategory = categoryFilter === 'All' || (s.category && s.category.startsWith(categoryFilter));
    
    return matchesSearch && matchesCategory;
  });

  const getCategoryColor = (category?: string) => {
    const mainCat = category?.split('>')[0].trim().toLowerCase() || '';
    
    if (mainCat.includes('cleaning') || mainCat.includes('home')) return 'bg-blue-50 text-blue-600 border-blue-100';
    if (mainCat.includes('plumbing')) return 'bg-cyan-50 text-cyan-600 border-cyan-100';
    if (mainCat.includes('electrical')) return 'bg-amber-50 text-amber-600 border-amber-100';
    if (mainCat.includes('automotive')) return 'bg-rose-50 text-rose-600 border-rose-100';
    if (mainCat.includes('moving')) return 'bg-purple-50 text-purple-600 border-purple-100';
    if (mainCat.includes('health')) return 'bg-emerald-50 text-emerald-600 border-emerald-100';
    if (mainCat.includes('pet')) return 'bg-pink-50 text-pink-600 border-pink-100';
    if (mainCat.includes('safety')) return 'bg-slate-50 text-slate-600 border-slate-100';
    if (mainCat.includes('event')) return 'bg-indigo-50 text-indigo-600 border-indigo-100';
    
    return 'bg-gray-50 text-gray-600 border-gray-100';
  };

  const exportToCSV = () => {
    const headers = [
      "Service ID",
      "Service Title",
      "Provider Name",
      "Provider ID",
      "Category",
      "Price (RM)",
      "Total Bookings",
      "Average Rating",
      "Status"
    ];

    const rows = filteredServices.map(s => {
      const stats = getServiceStats(s.id);
      const provider = users.find(u => u.id === s.providerId);
      return [
        s.customId || s.id,
        s.title || "Untitled",
        s.providerName || "Unknown",
        provider?.customId || s.providerId || "N/A",
        s.category || "N/A",
        Number(s.price).toFixed(2),
        stats.totalBookings,
        stats.avgRating,
        (s.isActive ?? true) ? "Active" : "Hidden"
      ];
    });

    const csvContent = [
      headers.join(","),
      ...rows.map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(","))
    ].join("\n");

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `GoServe_Services_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col xl:flex-row justify-between items-start xl:items-center gap-6">
        <div>
          <h1 className="text-lg font-bold text-gray-900 uppercase tracking-tight">Marketplace Services</h1>
          <div className="flex items-center gap-3">
            <p className="text-gray-500 text-sm font-medium">Monitoring active offerings ({filteredServices.length})</p>
            <button 
              onClick={migrateServiceIds}
              disabled={isMigrating}
              className={`text-[10px] font-bold uppercase tracking-widest transition-all ${isMigrating ? 'text-gray-400 cursor-not-allowed' : 'text-orange-500 hover:text-orange-600 underline'}`}
            >
              {isMigrating ? 'Migrating...' : 'Fix IDs'}
            </button>
            <span className="text-gray-300 text-[10px]">|</span>
            <button 
              onClick={recalculateRatings}
              disabled={isMigrating}
              className={`text-[10px] font-bold uppercase tracking-widest transition-all ${isMigrating ? 'text-gray-400 cursor-not-allowed' : 'text-orange-500 hover:text-orange-600 underline'}`}
            >
              {isMigrating ? 'Recalculating...' : 'Sync Ratings'}
            </button>
          </div>
        </div>

        <div className="flex flex-col md:flex-row items-center gap-4 w-full xl:w-auto">
          {/* Layout Toggle */}
          <div className="flex bg-white border border-gray-200 rounded-lg p-1 shadow-sm mr-2">
            <button 
              onClick={() => setLayout('grid')}
              className={`p-1.5 rounded-md transition-all ${layout === 'grid' ? 'bg-orange-500 text-white shadow-sm' : 'text-gray-400 hover:text-gray-600'}`}
              title="Grid View"
            >
              <LayoutGrid size={18} />
            </button>
            <button 
              onClick={() => setLayout('list')}
              className={`p-1.5 rounded-md transition-all ${layout === 'list' ? 'bg-orange-500 text-white shadow-sm' : 'text-gray-400 hover:text-gray-600'}`}
              title="List View"
            >
              <List size={18} />
            </button>
          </div>

          <div className="relative w-full md:w-80">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
            <input
              type="text"
              placeholder="Search services..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 bg-white border border-gray-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-orange-500/20 transition-all shadow-sm"
            />
          </div>

          <div className="flex items-center gap-2 w-full md:w-auto">
            <div className="relative w-full md:w-48">
              <Briefcase className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className="w-full pl-10 pr-4 py-2 bg-white border border-gray-200 rounded-lg text-sm font-bold text-gray-700 focus:outline-none focus:ring-2 focus:ring-orange-500/20 transition-all appearance-none shadow-sm"
              >
                <option value="All">All Categories</option>
                {categories.map(cat => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>

            <button
              onClick={exportToCSV}
              className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg text-sm font-bold hover:bg-orange-600 transition-all shadow-sm shadow-orange-100 whitespace-nowrap"
            >
              <Download size={18} />
              Export CSV
            </button>
            
            {(search || categoryFilter !== 'All') && (
              <button 
                onClick={() => { setSearch(''); setCategoryFilter('All'); }}
                className="p-2 text-gray-400 hover:text-orange-500 transition-colors"
                title="Reset Filters"
              >
                <RotateCcw size={18} />
              </button>
            )}
          </div>
        </div>
      </div>

      {filteredServices.length === 0 ? (
        <div className="py-20 bg-white rounded-xl border border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400">
          <Briefcase size={48} className="mb-4 opacity-20" />
          <p className="font-medium">No services found</p>
        </div>
      ) : layout === 'grid' ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
          {filteredServices.map((s) => (
            <div key={s.id} className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden flex flex-col group hover:shadow-xl hover:shadow-orange-500/5 transition-all duration-300">
              {/* Header Image */}
              <div className="relative h-40 bg-gray-50 overflow-hidden">
                {s.servicePhotoUrl ? (
                  <img src={s.servicePhotoUrl} alt={s.title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-gray-200">
                    <Briefcase size={40} className="opacity-10" />
                  </div>
                )}
                <div className="absolute top-4 right-4 flex gap-2">
                  <button
                    onClick={() => toggleStatus(s.id, s.isActive ?? true)}
                    className={`p-2 rounded-md backdrop-blur-md transition-all shadow-lg ${(s.isActive ?? true)
                        ? 'bg-emerald-500/90 text-white'
                        : 'bg-orange-500/90 text-white'
                      }`}
                  >
                    {(s.isActive ?? true) ? <Check size={18} /> : <EyeOff size={18} />}
                  </button>
                </div>
              </div>

              {/* Content */}
              <div className="p-5 flex flex-col flex-1">
                <div className="flex justify-between items-start mb-4">
                  <div className="flex-1">
                    <span className={`text-[10px] font-bold uppercase tracking-widest px-2 py-0.5 rounded border inline-block mb-2 ${getCategoryColor(s.category)}`}>
                      {s.category} {s.subcategory && `> ${s.subcategory}`}
                    </span>
                    <h3 className="text-lg font-bold text-gray-900 line-clamp-1">{s.title || 'Untitled Service'}</h3>
                    <p className="text-xs text-gray-400 font-medium">By {s.providerName || 'Unknown Provider'}</p>
                  </div>
                  <div className="flex flex-col items-end gap-1">
                    <div className="flex items-center gap-1 text-amber-500 font-bold text-sm">
                      <Star size={14} fill="currentColor" />
                      {getServiceStats(s.id).avgRating}
                    </div>
                    <span className="text-[10px] text-gray-400 font-bold uppercase">{getServiceStats(s.id).reviewCount} Reviews</span>
                  </div>
                </div>

                <div className="flex items-center gap-4 mb-6">
                  <div className="flex items-center gap-1.5 text-gray-500 text-xs font-semibold">
                    <Calendar size={14} />
                    {getServiceStats(s.id).totalBookings} Bookings
                  </div>
                </div>

                <p className="text-sm text-gray-500 line-clamp-2 mb-6 flex-1 italic leading-relaxed">
                  {s.description || 'No description provided.'}
                </p>

                <div className="pt-4 border-t border-gray-50 flex items-center justify-between mt-auto">
                  <span className="text-lg font-bold text-gray-900">RM {Number(s.price).toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                  <button
                    onClick={() => setSelectedService(s)}
                    className="px-4 py-2 bg-gray-900 text-white rounded-md text-xs font-bold hover:bg-orange-500 transition-colors flex items-center gap-2"
                  >
                    <Eye size={14} />
                    View Details
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
          <table className="w-full text-left">
            <thead>
              <tr className="bg-gray-50/50 border-b border-gray-100">
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Service</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Provider</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Category</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Bookings</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Rating</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Price</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Status</th>
                <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filteredServices.map((s) => {
                const stats = getServiceStats(s.id);
                const provider = users.find(u => u.id === s.providerId);
                return (
                  <tr key={s.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-lg bg-gray-100 overflow-hidden shrink-0">
                          {s.servicePhotoUrl ? (
                            <img src={s.servicePhotoUrl} alt={s.title} className="w-full h-full object-cover" />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-gray-300">
                              <Briefcase size={20} />
                            </div>
                          )}
                        </div>
                        <div className="min-w-0">
                          <p className="text-sm font-bold text-gray-900 truncate">{s.title || 'Untitled'}</p>
                          <p className="text-[10px] font-medium text-gray-400 line-clamp-1">{s.customId || s.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="min-w-0">
                        <p className="text-sm font-bold text-gray-900 truncate">{s.providerName || 'Unknown'}</p>
                        <p className="text-[10px] font-medium text-gray-400 truncate">{provider?.customId || s.providerId || 'No ID'}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider border ${getCategoryColor(s.category)}`}>
                        {s.category}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <div className="flex flex-col items-center gap-1">
                        <span className="text-sm font-bold text-gray-900">{stats.totalBookings}</span>
                        <span className="text-[10px] font-bold text-gray-400 uppercase tracking-tight">Bookings</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <div className="flex flex-col items-center gap-1">
                        <div className="flex items-center gap-1 text-sm font-bold text-gray-900">
                          <Star size={12} className="text-amber-500" fill="currentColor" />
                          {stats.avgRating}
                        </div>
                        <span className="text-[10px] font-bold text-gray-400 uppercase tracking-tight">{stats.reviewCount} Reviews</span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className="text-sm font-bold text-gray-900">RM {Number(s.price).toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                    </td>
                  <td className="px-6 py-4">
                    <div className="flex justify-center">
                      <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold flex items-center gap-1.5 ${(s.isActive ?? true) ? 'bg-emerald-50 text-emerald-600' : 'bg-orange-50 text-orange-600'}`}>
                        <div className={`w-1.5 h-1.5 rounded-full ${(s.isActive ?? true) ? 'bg-emerald-500' : 'bg-orange-500'}`} />
                        {(s.isActive ?? true) ? 'Active' : 'Hidden'}
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center justify-end gap-2">
                      <button 
                        onClick={() => toggleStatus(s.id, s.isActive ?? true)}
                        className={`p-2 rounded-lg transition-colors ${(s.isActive ?? true) ? 'text-gray-400 hover:text-orange-500 hover:bg-orange-50' : 'text-orange-500 bg-orange-50 hover:bg-orange-100'}`}
                        title={(s.isActive ?? true) ? 'Hide Service' : 'Show Service'}
                      >
                        {(s.isActive ?? true) ? <EyeOff size={16} /> : <Eye size={16} />}
                      </button>
                      <button 
                        onClick={() => setSelectedService(s)}
                        className="p-2 text-gray-400 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
                        title="View Details"
                      >
                        <FileText size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* DETAIL MODAL */}
      {selectedService && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setSelectedService(null)} />
          <div className="relative bg-white w-full max-w-4xl max-h-[90vh] rounded-2xl overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 overflow-y-auto">
            <button
              onClick={() => setSelectedService(null)}
              className="absolute top-6 right-6 z-10 p-2 bg-white/80 backdrop-blur-md rounded-full text-gray-900 hover:bg-gray-100 transition-all"
            >
              <X size={24} />
            </button>

            <div className="grid grid-cols-1 lg:grid-cols-2">
              <div className="h-64 lg:h-auto bg-gray-100">
                <img src={selectedService.servicePhotoUrl} alt={selectedService.title} className="w-full h-full object-cover" />
              </div>
              <div className="p-8 lg:p-12 space-y-8">
                <div>
                  <span className="text-sm font-bold text-orange-500 uppercase tracking-widest">{selectedService.category}</span>
                  <h2 className="text-4xl font-extrabold text-gray-900 mt-2">{selectedService.title}</h2>
                  <p className="text-gray-500 mt-2 font-medium">
                    Provided by <span className="text-gray-900 font-bold">{selectedService.providerName}</span>
                    <span className="text-[10px] text-gray-400 font-bold uppercase ml-2 px-1.5 py-0.5 bg-gray-100 rounded">
                      {users.find(u => u.id === selectedService.providerId)?.customId || selectedService.providerId}
                    </span>
                  </p>
                </div>

                <div className="text-3xl font-bold text-gray-900">RM {Number(selectedService.price).toLocaleString(undefined, { minimumFractionDigits: 2 })}</div>

                <div className="space-y-4">
                  <h4 className="font-bold text-gray-900 flex items-center gap-2">
                    <div className="w-1.5 h-5 bg-orange-500 rounded-full" />
                    About this service
                  </h4>
                  <p className="text-sm text-gray-600 leading-relaxed italic">"{selectedService.description}"</p>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                  <div className="space-y-3">
                    <h4 className="text-xs font-bold text-gray-400 uppercase tracking-widest">Includes</h4>
                    <div className="space-y-2">
                      {(selectedService.details || []).map((item, i) => (
                        <div key={i} className="flex items-center gap-2 text-xs text-gray-600 font-medium">
                          <Check size={14} className="text-emerald-500" /> {item}
                        </div>
                      ))}
                    </div>
                  </div>
                  <div className="space-y-3">
                    <h4 className="text-xs font-bold text-gray-400 uppercase tracking-widest">Add-ons</h4>
                    <div className="space-y-2">
                      {(selectedService.addOns || []).map((addon, i) => (
                        <div key={i} className="flex items-center justify-between text-xs text-gray-600 font-medium p-2 bg-gray-50 rounded">
                          <span>{addon.name}</span>
                          <span className="font-bold text-orange-500">+RM{addon.price}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <h4 className="text-xs font-bold text-gray-400 uppercase tracking-widest">Gallery</h4>
                  <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
                    {(selectedService.galleryUrls || []).map((url, i) => (
                      <img key={i} src={url} className="h-20 w-20 rounded-md object-cover border border-gray-100 shrink-0 shadow-sm" />
                    ))}
                  </div>
                </div>

                <div className="pt-8 border-t border-gray-100 mt-8">
                  <button 
                    onClick={() => handleDeleteService(selectedService.id)}
                    className="w-full py-3.5 bg-red-50 text-red-500 rounded-xl font-black text-sm hover:bg-red-500 hover:text-white transition-all uppercase tracking-widest flex items-center justify-center gap-2"
                  >
                    <Trash2 size={16} />
                    Permanently Delete Service
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function PaymentsPage({ bookings, users }: { bookings: Booking[], users: AppUser[] }) {
  const [loading, setLoading] = useState<string | null>(null);

  const completedBookings = bookings.filter(b => b.status === 'Completed');
  const pendingPayouts = completedBookings.filter(b => (b as any).payoutStatus !== 'transferred');
  const completedPayouts = completedBookings.filter(b => (b as any).payoutStatus === 'transferred');

  const totalEscrow = pendingPayouts.reduce((acc, b) => acc + (b.totalPrice || 0), 0);
  const totalTransferred = completedPayouts.reduce((acc, b) => acc + ((b.totalPrice || 0) - (b.chargeFee || 0)), 0);
  const totalPlatformFees = completedPayouts.reduce((acc, b) => acc + (b.chargeFee || 0), 0);

  const handleTransfer = async (bookingId: string) => {
    if (!window.confirm('Are you sure you want to process this transfer to the provider?')) return;
    
    setLoading(bookingId);
    try {
      const b = bookings.find(item => item.id === bookingId);
      const payoutAmount = (b?.totalPrice || 0) - (b?.chargeFee || 0);
      
      await updateDoc(doc(db, 'bookings', bookingId), {
        payoutStatus: 'transferred',
        payoutAt: new Date(),
        payoutAmount: payoutAmount
      });

      // Email Notification Logic
      const providerUser = users.find(u => u.id === b?.providerId);
      const providerEmail = providerUser?.email;

      if (providerEmail) {
        const orderIdStr = b?.orderId || b?.id.substring(0, 8);
        const subject = `Payout Processed for Booking ${orderIdStr}`;
        const text = `Hello ${b?.providerName},\n\nWe have successfully processed the payout for your completed service (Order ID: ${orderIdStr}).\n\nAmount Transferred: RM ${payoutAmount.toLocaleString()}\nDate: ${new Date().toLocaleDateString()}\n\nThe funds should reflect in your earnings in GoServe application shortly.\n\nThank you for your excellent service!\n\nBest Regards,\nGoServe Admin Team`;
        
        // Write to Firebase 'mail' collection to automatically trigger the email extension in the background
        await addDoc(collection(db, 'mail'), {
          to: providerEmail,
          message: {
            subject: subject,
            text: text
          }
        });
        
        alert('Transfer processed successfully! An email notification has been automatically sent to the provider.');
      } else {
        alert("Transfer processed successfully! However, the provider's email was not found to send a notification.");
      }
    } catch (e) {
      console.error(e);
      alert('Transfer failed');
    } finally {
      setLoading(null);
    }
  };

  const exportToCSV = () => {
    const headers = ['Order ID', 'Provider', 'Service', 'Total Price', 'Platform Fee', 'Payout Amount', 'Payout Status'];
    const csvContent = [
      headers.join(','),
      ...completedBookings.map((b: any) => {
        const payoutAmount = (b.totalPrice || 0) - (b.chargeFee || 0);
        return [
          b.orderId || '',
          `"${b.providerName || ''}"`,
          `"${b.serviceName || ''}"`,
          b.totalPrice || '',
          b.chargeFee || '',
          payoutAmount,
          b.payoutStatus || 'pending'
        ].join(',');
      })
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.setAttribute('download', `goserve_payments_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-8 animate-premium-in">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
        <div>
          <h1 className="text-xl font-bold text-slate-900">Payment Management</h1>
          <p className="text-slate-500 text-sm">Monitor escrow and manage provider payouts</p>
        </div>
        <div className="flex items-center gap-3 w-full md:w-auto">
          <button 
            onClick={exportToCSV}
            className="flex-1 md:flex-none flex items-center justify-center gap-2 px-4 py-2.5 bg-orange-500 text-white rounded-lg text-sm font-bold hover:bg-orange-600 transition-all shadow-sm shadow-orange-100"
          >
            <Download size={18} />
            Export CSV
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm">
          <div className="flex items-center gap-4 mb-4">
            <div className="p-3 bg-amber-50 text-amber-600 rounded-2xl">
              <Wallet size={20} />
            </div>
            <div>
              <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Escrow Balance</p>
              <p className="text-2xl font-black text-slate-900">RM {totalEscrow.toLocaleString()}</p>
            </div>
          </div>
          <p className="text-[10px] text-slate-400 font-medium">Funds held for completed but unpaid bookings</p>
        </div>

        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm">
          <div className="flex items-center gap-4 mb-4">
            <div className="p-3 bg-emerald-50 text-emerald-600 rounded-2xl">
              <Check size={20} />
            </div>
            <div>
              <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Total Payouts</p>
              <p className="text-2xl font-black text-slate-900">RM {totalTransferred.toLocaleString()}</p>
            </div>
          </div>
          <p className="text-[10px] text-slate-400 font-medium">Total funds successfully sent to providers</p>
        </div>

        <div className="bg-white p-6 rounded-3xl border border-slate-100 shadow-sm">
          <div className="flex items-center gap-4 mb-4">
            <div className="p-3 bg-indigo-50 text-indigo-600 rounded-2xl">
              <TrendingUp size={20} />
            </div>
            <div>
              <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Platform Fees</p>
              <p className="text-2xl font-black text-slate-900">RM {totalPlatformFees.toLocaleString()}</p>
            </div>
          </div>
          <p className="text-[10px] text-slate-400 font-medium">Earnings from customer charge fees</p>
        </div>
      </div>

      <div className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden">
        <div className="p-8 border-b border-slate-50 flex items-center justify-between">
          <h3 className="font-bold text-slate-900 text-lg">Pending Provider Transfers</h3>
          <span className="px-3 py-1 bg-amber-50 text-amber-600 rounded-full text-[10px] font-black uppercase">{pendingPayouts.length} Pending</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-50">
                <th className="px-8 py-4">Provider</th>
                <th className="px-6 py-4">Booking ID</th>
                <th className="px-6 py-4">Total Received</th>
                <th className="px-6 py-4">Charge Fee</th>
                <th className="px-6 py-4">Payout Amount</th>
                <th className="px-8 py-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {pendingPayouts.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-8 py-20 text-center text-slate-400 font-medium italic">No pending transfers found</td>
                </tr>
              ) : (
                pendingPayouts.map((b) => {
                  const fee = b.chargeFee || 0;
                  const payout = (b.totalPrice || 0) - fee;
                  return (
                    <tr key={b.id} className="group hover:bg-slate-50/50 transition-colors">
                      <td className="px-8 py-5">
                        <p className="text-sm font-bold text-slate-900">{b.providerName}</p>
                        <p className="text-[10px] text-slate-400 font-bold uppercase">{users.find(u => u.id === b.providerId)?.customId || 'PR-UNKNOWN'}</p>
                      </td>
                      <td className="px-6 py-5">
                        <p className="text-xs font-bold text-slate-500 uppercase">{b.orderId || b.id.substring(0, 8)}</p>
                        <p className="text-[10px] text-slate-400 font-medium">Completed: {new Date(b.date).toLocaleDateString()}</p>
                      </td>
                      <td className="px-6 py-5 text-sm font-bold text-slate-900">RM {b.totalPrice?.toLocaleString()}</td>
                      <td className="px-6 py-5 text-sm font-bold text-rose-500">- RM {fee.toLocaleString()}</td>
                      <td className="px-6 py-5 text-sm font-black text-emerald-600">RM {payout.toLocaleString()}</td>
                      <td className="px-8 py-5 text-right">
                        <button
                          onClick={() => handleTransfer(b.id)}
                          disabled={loading === b.id}
                          className="px-4 py-2 bg-slate-900 text-white rounded-xl text-[10px] font-bold uppercase tracking-widest hover:bg-emerald-600 transition-all shadow-lg shadow-slate-900/10 flex items-center gap-2 ml-auto"
                        >
                          {loading === b.id ? (
                            <div className="w-3 h-3 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                          ) : (
                            <RefreshCcw size={14} />
                          )}
                          Process Transfer
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden mt-8">
        <div className="p-8 border-b border-slate-50 flex items-center justify-between">
          <h3 className="font-bold text-slate-900 text-lg">Payout History</h3>
          <span className="px-3 py-1 bg-emerald-50 text-emerald-600 rounded-full text-[10px] font-black uppercase">{completedPayouts.length} Transferred</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-50">
                <th className="px-8 py-4">Provider</th>
                <th className="px-6 py-4">Booking ID</th>
                <th className="px-6 py-4">Total Paid</th>
                <th className="px-6 py-4">Charge Fee</th>
                <th className="px-6 py-4">Amount Sent</th>
                <th className="px-8 py-4 text-right">Transfer Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {completedPayouts.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-8 py-20 text-center text-slate-400 font-medium italic">No payout history found</td>
                </tr>
              ) : (
                completedPayouts.sort((a: any, b: any) => {
                  const dateA = a.payoutAt?.seconds ? a.payoutAt.seconds : 0;
                  const dateB = b.payoutAt?.seconds ? b.payoutAt.seconds : 0;
                  return dateB - dateA;
                }).map((b: any) => {
                  const fee = b.chargeFee || 0;
                  const payout = (b.totalPrice || 0) - fee;
                  return (
                    <tr key={b.id} className="group hover:bg-slate-50/50 transition-colors">
                      <td className="px-8 py-5">
                        <p className="text-sm font-bold text-slate-900">{b.providerName}</p>
                        <p className="text-[10px] text-slate-400 font-bold uppercase">{users.find(u => u.id === b.providerId)?.customId || 'PR-UNKNOWN'}</p>
                      </td>
                      <td className="px-6 py-5">
                        <p className="text-xs font-bold text-slate-500 uppercase">{b.orderId || b.id.substring(0, 8)}</p>
                        <p className="text-[10px] text-slate-400 font-medium">Completed: {new Date(b.date).toLocaleDateString()}</p>
                      </td>
                      <td className="px-6 py-5 text-sm font-bold text-slate-900">RM {b.totalPrice?.toLocaleString()}</td>
                      <td className="px-6 py-5 text-sm font-bold text-rose-500">- RM {fee.toLocaleString()}</td>
                      <td className="px-6 py-5 text-sm font-black text-emerald-600">RM {payout.toLocaleString()}</td>
                      <td className="px-8 py-5 text-right text-xs font-bold text-slate-500">
                        {b.payoutAt?.seconds ? new Date(b.payoutAt.seconds * 1000).toLocaleDateString() : 'Unknown Date'}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function ReportsPage({ reports }: { reports: Report[] }) {
  const [loadingId, setLoadingId] = useState<string | null>(null);

  const handleResolve = async (id: string) => {
    setLoadingId(id);
    try {
      await updateDoc(doc(db, 'reports', id), { status: 'resolved' });
    } catch (e: any) {
      alert(`Failed to resolve: ${e.message}`);
    } finally {
      setLoadingId(null);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this report?')) return;
    try {
      await updateDoc(doc(db, 'reports', id), { status: 'deleted' }); // or deleteDoc
      // Actually let's just delete it
      const { deleteDoc } = await import('firebase/firestore');
      await deleteDoc(doc(db, 'reports', id));
    } catch (e: any) {
      alert(`Failed to delete: ${e.message}`);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-lg font-bold text-gray-900 uppercase">Customer Reports</h1>
          <p className="text-gray-500 text-sm font-medium">Tracking and resolving platform issues ({reports.length})</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
        {reports.length === 0 ? (
          <div className="py-20 flex flex-col items-center justify-center text-gray-400">
            <Check size={48} className="mb-4 opacity-20" />
            <p className="font-medium">No pending reports</p>
            <p className="text-xs">Great job! All customer issues are cleared.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="bg-gray-50/50 border-b border-gray-100">
                  <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Customer</th>
                  <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Provider</th>
                  <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Report Detail</th>
                  <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Date</th>
                  <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">Status</th>
                  <th className="px-6 py-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {reports.map((rpt) => (
                  <tr key={rpt.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        {rpt.customerProfileUrl ? (
                          <img src={rpt.customerProfileUrl} alt={rpt.customerName} className="w-8 h-8 rounded-full object-cover border border-gray-200" />
                        ) : (
                          <div className="w-8 h-8 rounded-full bg-orange-100 text-orange-600 flex items-center justify-center font-bold text-xs">
                            {rpt.customerName?.[0]?.toUpperCase()}
                          </div>
                        )}
                        <div>
                          <p className="text-sm font-bold text-gray-900">{rpt.customerName}</p>
                          <p className="text-[10px] text-gray-500 uppercase">{rpt.customerCustomId || 'CU-PENDING'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-sm font-bold text-gray-900">{rpt.providerName}</p>
                        <p className="text-[10px] text-gray-500 uppercase">{rpt.providerCustomId || 'PR-PENDING'}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="max-w-xs">
                        <p className="text-xs font-bold text-gray-800 truncate">{rpt.serviceName}</p>
                        <p className="text-[10px] text-gray-500 truncate italic mt-0.5">"{rpt.issue}"</p>
                        <p className="text-[9px] font-bold text-orange-600 uppercase mt-1">Order ID: {rpt.orderId}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-1.5 text-[10px] font-bold text-gray-500 uppercase">
                        <Clock size={12} className="text-gray-400" />
                        {rpt.timestamp?.seconds ? new Date(rpt.timestamp.seconds * 1000).toLocaleDateString() : 'Just now'}
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className={`inline-flex px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest ${
                        rpt.status === 'resolved' 
                        ? 'bg-emerald-50 text-emerald-600 border border-emerald-100' 
                        : 'bg-amber-50 text-amber-600 border border-amber-100 animate-pulse'
                      }`}>
                        {rpt.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        {rpt.status !== 'resolved' && (
                          <button
                            onClick={() => handleResolve(rpt.id)}
                            disabled={loadingId === rpt.id}
                            className="p-2 text-emerald-600 hover:bg-emerald-50 rounded-lg transition-colors"
                            title="Mark Resolved"
                          >
                            {loadingId === rpt.id ? (
                              <div className="animate-spin h-4 w-4 border-2 border-emerald-600 border-t-transparent rounded-full" />
                            ) : (
                              <Check size={18} />
                            )}
                          </button>
                        )}
                        <button
                          onClick={() => handleDelete(rpt.id)}
                          className="p-2 text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                          title="Delete Report"
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

function LoginPage() {
  const [email, setEmail] = useState('admin@goserve.com');
  const [password, setPassword] = useState('AdminGoServe123');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err: any) {
      setError('Invalid credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="h-screen w-screen flex items-center justify-center bg-gray-50 text-gray-900">
      <div className="w-full max-w-sm bg-white rounded-xl p-10 shadow-xl text-center">
        <div className="w-20 h-20 bg-orange-500 rounded-xl flex items-center justify-center mx-auto mb-8 shadow-lg shadow-orange-100">
          <ShieldCheck size={40} className="text-white" />
        </div>
        <h2 className="text-xl font-bold text-gray-900 mb-2">Welcome Back</h2>
        <p className="text-gray-500 text-sm mb-10">Login to access the admin console</p>

        {error && <div className="mb-6 p-3 bg-red-50 text-red-500 text-xs font-bold rounded-md border border-red-100">{error}</div>}

        <form onSubmit={handleLogin} className="space-y-6 text-left">
          <div className="space-y-2">
            <label className="text-[13px] font-medium text-gray-500 px-1">Email address</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-5 py-4 bg-gray-50 border-none rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500 font-medium text-base text-gray-900 transition-all placeholder:text-gray-300"
              placeholder="name@example.com"
              required
            />
          </div>

          <div className="space-y-2">
            <label className="text-[13px] font-medium text-gray-500 px-1">Password</label>
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-5 py-4 bg-gray-50 border-none rounded-2xl focus:outline-none focus:ring-2 focus:ring-orange-500 font-medium text-base text-gray-900 transition-all"
                placeholder="••••••••••••"
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 focus:outline-none transition-colors"
              >
                {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
              </button>
            </div>
          </div>

          <button type="submit" disabled={loading} className="w-full py-4.5 bg-orange-500 text-white rounded-2xl font-bold text-base shadow-lg shadow-orange-100 hover:bg-orange-600 active:scale-[0.98] transition-all mt-4">
            {loading ? 'Entering System...' : 'Login'}
          </button>
        </form>
      </div>
    </div>
  );
}

export default App;
